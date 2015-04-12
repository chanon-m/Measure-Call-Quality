#!/usr/bin/perl -w
#rtptest.pl 
#Chanon M

use strict;
use Net::RTP;
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
        my $pkt_loss = 0;

        #Listen RTP packets
        while(my $rtp_packet = $rtp->recv()) {

                #The RTP timestamp from packet i
                $jitter{S}[0] = $jitter{S}[1];
                $jitter{S}[1] = $rtp_packet->timestamp();
                $jitter{S}[0] = $rtp_packet->timestamp() if($jitter{S}[0] == 0);

                #The time of arrival in RTP timestamp units from packet i
                $jitter{R}[0] = $jitter{R}[1];
                $jitter{R}[1] = time();
                $jitter{R}[0] = $jitter{R}[1] if($jitter{R}[0] == 0);

                $jitter{SEQ}[0] = $jitter{SEQ}[1];
                $jitter{SEQ}[1] = $rtp_packet->seq_num();
                if($jitter{SEQ}[1] == 1) { #initial variable at first rtp packet
                    $jitter{SEQ}[0] = 0;
                    $jitter{J}[0] = 0;
                    $jitter{D} = 0;
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
                    $diff_SEQ = abs($diff_SEQ);
                    $pkt_loss += $diff_SEQ if($jitter{SEQ}[0] != 0);
                }

                #Display results
                printf "%u RTP Payload = %u bytes, ", $jitter{SEQ}[1], $rtp_packet->payload_size();
                printf "from %s:%s ", $rtp_packet->source_ip(), $rtp_packet->source_port();
                printf "Jitter = %2.4f, Packet Loss = %u \n",  $jitter{J}[1], $pkt_loss;

                $jitter{J}[0] =  $jitter{J}[1];
      }
      
}

sub client {

        my $rtp = new Net::RTP(
                               PeerPort=>$port,
                               PeerAddr=>$ipaddr
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
