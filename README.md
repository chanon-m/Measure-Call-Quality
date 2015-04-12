# Measure-Call-Quality
Measure Call Quality between end points

####Jitter
Normally VOIP devices send out one RTP packet per 20ms. In Figure shows the RTP stream at a receiver side. The packets do not arrive on time, caused by network congestion or route changes. So the quality of the audio will be bad. Time difference in packet inter arrival time at the end device can be called jitter. 


![Alt text](http://www.icalleasy.com/images/jitter1.png "Jitter") 





Jitter is measured in timestamp units. The formula of jitter can be:

```

J(i) = J(i-1) + ( |D(i-1,i)| - J(i-1) )/16

```

D(i-1,i) is the difference of relative transit times for the two packets. The formula is:

````

D(i-1,i) = Ri - ( R(i-1) + (Si - S(i-1)) )

Si is the RTP timestamp from packet i
Ri is the time of arrival in RTP timestamp units from packet i

````

####MOS Score
MOS (Mean Opinion Score) is call quality metric in VOIP industry. It provides a numerical to measure the Quality of Service in Voice Over IP (VOIP). The score range can be from 1 for an unacceptable call to 5 for an excellent call. The key factors that effect the quality of call are latency, packet loss and jitter. So the formula I use is in below.

```
# The R-value for G711 codec is 93.
R = 93

# Latency effect. deduct 5 for a delay of 150 ms, 20 for a delay of 240 ms, 30 for a delay of 360 ms.
If Latency < 150 
     R = 93 - (Latency / 30)
else
     R = 93 - (Latency / 12)   
     
# Deduct 7.5 R-value per Packet Loss. 
R = R - (7.5 * Packet Loss)

# Deduct Jitter
R = R - Jitter

```

#How to run file

* Download files on your servers

```

# git clone https://github.com/chanon-m/Measure-Call-Quality.git

```

* Make a file executable  

```

# chmod 755 ./Measure-Call-Quality/rtptester.pl

```

* Run rtptester.pl as server

```

# ./Measure-Call-Quality/rtptester.pl -s [local ip address] [port number]

```

* Run rtptester.pl on remote site

```

# ./Measure-Call-Quality/rtptester.pl -c [server ip address] [port number] [count]

```
