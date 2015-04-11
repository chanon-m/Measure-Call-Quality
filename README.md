# Measure-Call-Quality
Measure Call Quality between end points

Normally VOIP devices send out one RTP packet per 20ms. In Figure shows the RTP stream at a receiver device. The packets do not arrive on time, caused by network congestion or route changes. So the quality of the audio will be bad. Time difference in packet inter arrival time at end device can be called jitter. 


![Alt text](http://www.icalleasy.com/images/jitter1.png "Jitter") 





Jitter is measured in timestam units. The formula of jitter can be:

```

J(i) = J(i-1) + ( |D(i-1,i)| - J(i-1) )/16

```

D(i-1,i) is the difference of relative transit times for the two packets. The formula is:

````

D(i-1,i) = Ri - ( R(i-1 + (Si - S(i-1)) )

Si is the RTP timestamp from packet i
Ri is the time of arrival in RTP timestamp units from packet i

````
