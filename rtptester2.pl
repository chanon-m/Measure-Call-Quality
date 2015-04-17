#!/usr/bin/perl -w
#rtptester2.pl
#A new feature: report in both sites
#Chanon M

use strict;
use Net::RTP;
use Net::Address::IP::Local;
use Time::HiRes qw(usleep);

my ($mode, $ipaddr, $port, $count);

usage();

if($mode eq "-s") {
    server();
} else {
    client();
}

sub server {

        my $rtp = new Net::RTP(
                               LocalPort=>$port,
                               LocalAddr=>$ipaddr
                      ) || die "Failed to create RTP socket: $!";
        my %jitter = (
            R    => [ 0, 0 ],
            S    => [ 0, 0 ],
            J    => [ 0, 0 ],
            SEQ  => [ 0, 0 ],
            D    =>   0,
        );
        my ($latency,$pkt_loss,$avejitter,$count) = (0,0,0,0);

        #Listen RTP packets
        while(my $rtp_packet = $rtp->recv()) {

            if(!$rtp_packet->marker()) {
                #The RTP timestamp from packet i
                ($jitter{S}[0],$jitter{S}[1]) = ($jitter{S}[1],$rtp_packet->timestamp());
                $jitter{S}[0] = $rtp_packet->timestamp() if($jitter{S}[0] == 0);

                #The time of arrival in RTP timestamp units from packet i
                ($jitter{R}[0],$jitter{R}[1]) = ($jitter{R}[1],time());
                $jitter{R}[0] = $jitter{R}[1] if($jitter{R}[0] == 0);

                ($jitter{SEQ}[0],$jitter{SEQ}[1]) = ($jitter{SEQ}[1],$rtp_packet->seq_num());
                if($jitter{SEQ}[1] == 1) { #initial variable at first rtp packet
                    ($jitter{SEQ}[0],$jitter{J}[0],$jitter{D}) = (0,0,0);
                } else {
                    #Calculate the difference of relative transit times for the two packets
                    $jitter{D} = abs($jitter{R}[1] - ($jitter{R}[0] + ($jitter{S}[1] - $jitter{S}[0])))/1000;
                }

                my $diff_SEQ = $jitter{SEQ}[1] - $jitter{SEQ}[0];
                if($diff_SEQ == 1) {
                    #Calculate jitter with timestamp
                    $jitter{J}[1] = $jitter{J}[0] + (($jitter{D} - $jitter{J}[0])/16);
                } else {
                    $jitter{J}[1] = 0;
                    $diff_SEQ = abs($diff_SEQ) - 1 if(abs($diff_SEQ) > 0);
                    $pkt_loss += $diff_SEQ if($jitter{SEQ}[0] != 0);
                }

                Display_result($jitter{SEQ}[1], $rtp_packet->payload_size(), $rtp_packet->source_ip(),
                                $rtp_packet->source_port(),$jitter{J}[1], $pkt_loss);

                $jitter{J}[0] =  $jitter{J}[1];

                $avejitter += $jitter{J}[1];
                $latency += ($jitter{R}[1] - $jitter{R}[0]);
                $count++;
            } else {
                $latency = ($latency/$count) - 0.02;
                $latency = 0 if($latency < 0);
                $avejitter /= $count;

                #Calculate R-value
                my $R = Rvalue($latency,$pkt_loss,$avejitter,$count);

                #Convert R-value to MOS
                my $MOS = R2MOS($R);

                Call_Quality_report($MOS,$R,$latency,$pkt_loss,$avejitter,$rtp_packet->source_ip());

                ($latency,$pkt_loss,$avejitter,$count) = (0,0,0,0);
                ($jitter{R}[0],$jitter{R}[1]) = (0,0);

            }
      }

}

sub client {

        my $rtp = new Net::RTP(
                               PeerPort=>$port,
                               PeerAddr=>$ipaddr,
                      ) || die "Failed to create RTP socket: $!";

        #Create RTP packet
        my $packet = new Net::RTP::Packet();
        $packet->payload_type(0); #payload type is u-law

        #G711 codec and 20ms sample period
        my @data = 0 x 160; #G711 payload is 160 byte, dummy payload

        $packet->payload(@data);
        $packet->seq_num(0); #start seq number

        while($count) {
                $packet->seq_num_increment();
                #G711 sample rate 8KHz, sec = timestamp % rate = 177
                $packet->timestamp_increment(177);
                my $sent = $rtp->send($packet); #Send RTP packet

                #send RTP packet every 20ms
                usleep(20000);
                $count--;
        }

        $packet->marker(1);
        $rtp->send($packet);

        my $local_ip = Net::Address::IP::Local->public;
        Received_report($local_ip,$port);
}

sub Received_report {
        my ($r_ipaddr,$r_port) = ($_[0], $_[1]+1);
        my $rtp = new Net::RTP(
                               LocalPort=>$r_port,
                               LocalAddr=>$r_ipaddr
                      ) || die "Failed to create RTP socket: $!";

        my $rtp_packet = $rtp->recv();
        my $data = $rtp_packet->payload();

        print "Host: " . $rtp_packet->source_ip() . ":" . $rtp_packet->source_port() . "\n";
        print $data;

}

sub Display_result {
        my @report = @_;

        printf "%u RTP Payload = %u bytes, ", $report[0], $report[1];
        printf "from %s:%s ", $report[2], $report[3];
        printf "Jitter = %2.4f, Packet Loss = %u \n",  $report[4], $report[5];
}

sub Rvalue {
        my ($latency,$pkt_loss,$avejitter,$count) = ($_[0],$_[1],$_[2],$_[3]);

        my $R = 93; #R-value of G711

        # Latency effect. deduct 5 for a delay of 150 ms, 20 for a delay of 240 ms, 30 for a delay of 360 ms.
        if($latency < 150) {
            $R = $R - ($latency / 30);
        } else {
            $R = $R - ($latency / 12);
        }

        # Deduct 7.5 R-value per Packet Loss.
        $R -= 7.5 * $pkt_loss;
        # Deduct R-value with Jitter
        $R -= $avejitter;

        return $R;
}

sub R2MOS {
         my $R = $_[0];
         my ($Rmax,$Rmin,$MOSmax,$MOSmin) = (100,90,5,4.2);

        ($Rmax,$Rmin,$MOSmax,$MOSmin) = (90,80,4.3,3.9) if($R > 80 && $R <= 90);
        ($Rmax,$Rmin,$MOSmax,$MOSmin) = (80,70,4.0,3.5) if($R > 70 && $R <= 80);
        ($Rmax,$Rmin,$MOSmax,$MOSmin) = (70,60,3.6,3.0) if($R > 60 && $R <= 70);
        ($Rmax,$Rmin,$MOSmax,$MOSmin) = (60,50,3.1,2.5) if($R > 50 && $R <= 60);
        ($Rmax,$Rmin,$MOSmax,$MOSmin) = (50,0,2.6,0.9) if($R <= 50);

        my $MOS = ((($R - $Rmin) * ($MOSmax - $MOSmin)) / ($Rmax - $Rmin)) + $MOSmin;

        return $MOS;
}

sub Call_Quality_report {
        my @report = @_;

        my $port2 = $port + 1;

        my $rtp = new Net::RTP(
                               PeerPort=>$port2,
                               PeerAddr=>$report[5]
                      ) || die "Failed to create RTP socket: $!";

        usleep(200000);

        my $data = "-----------------------\n";
          $data .= "Call quality: \n";
          $data .= sprintf("MOS = %.1f \n", $report[0]);
          $data .= sprintf("R-value = %.2f \n", $report[1]);
          $data .= sprintf("Latency = %.2f ms \n", $report[2]);
          $data .= sprintf("Packet Loss = %u \n", $report[3]);
          $data .= sprintf("Jitter = %2.4f \n", $report[4]);
          $data .= "-----------------------\n";

        #Create RTP packet
        my $packet = new Net::RTP::Packet();
        $packet->payload($data);
        my $sent = $rtp->send($packet); #Send report

        print $data;

}

sub usage {

        if((scalar (@ARGV) == 3) || (scalar (@ARGV) == 4) && (($ARGV[0] eq "-s") || ($ARGV[0] eq "-c"))) {
            ($mode, $ipaddr, $port, $count) = @ARGV;
            $count = -1 if(!defined $count)
        } else {
            print "usage:   rtptester.pl [-s | -c] [IP Address] [port] [count]\n";
            print "             -s      server mode\n";
            print "             -c      client mode\n";
            print "example: rtptester.pl -s 127.0.0.1 7880 100\n";
            exit;
        }

}
