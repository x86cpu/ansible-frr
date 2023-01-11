#!/usr/bin/perl
#
#
use strict;

my $hostname=`hostname -s`;chomp($hostname);

my $tmp;
#my $tmp=`grep 'neighbor ' /etc/frr/frr.conf | awk '{printf $2"\\n"}' | sort -u | tr '\\n' ' '`;
my $tmp=`grep 'neighbor ' /etc/frr/frr.conf | awk '{printf \$2"\\n"}' | sort -u`;

my $tmp=`grep 'neighbor ' /etc/frr/frr.conf | grep ' description ' | awk '{printf \$4"\\n"}' | sort -u`;
chomp($tmp);
my @rtrs=split('\n',$tmp);

my $tmp=`grep 'neighbor ' /etc/frr/frr.conf | awk '{printf \$2"\\n"}' | sort -u`;
chomp($tmp);
my @neighbors=split('\n',$tmp);

my $neighbor;
my $rtr;

foreach $rtr ( @rtrs ) {
   unlink("/etc/frr/${rtr}.juniper");
}

my ($peerip,$peerpw,$peerroute,@prefix,$prefix);

open(IN,"/etc/frr/frr.conf");
foreach $neighbor ( @neighbors ) {
   $tmp=`grep 'neighbor ${neighbor} ' /etc/frr/frr.conf | grep ' description '`;chomp($tmp);
   $rtr=(split(' ',$tmp))[3];
   open(OUT,">>/etc/frr/${rtr}.juniper");
   $tmp=`grep 'neighbor ${neighbor} ' /etc/frr/frr.conf | grep ' update-source '`;chomp($tmp);
   $peerip=(split(' ',$tmp))[3];
   if ( $peerip =~ /:/ ) {
      print OUT "# $rtr V6\n";
      print OUT "set firewall family inet6 filter Router_Access_v6 term bgp_systems from source-address ${peerip}/128\n";
   } else {
      print OUT "# $rtr\n";
      print OUT "set firewall filter Router_Access term bgp_systems from source-address ${peerip}/32\n";
   }
   $tmp=`grep 'neighbor ${neighbor} ' /etc/frr/frr.conf | grep ' password '`;chomp($tmp);
   $peerpw=(split(' ',$tmp))[3];

   $peerroute=$hostname;
   if ( $hostname =~ /cs[123]test/ ) {
      $peerroute="cstest";
   } elsif ( $hostname =~ /cs[123]/ ) {
      $peerroute="csprod";
   } elsif ( $hostname =~ /ritwebfe01/ ) {
      $peerroute="www";
   } elsif ( $hostname =~ /ritwebfe02/ ) {
      $peerroute="ritwebfe02";
   } elsif ( $hostname =~ /shibtest/ ) {
      $peerroute="shibtest";
   } elsif ( $hostname =~ /mysql01-db/ ) {
      $peerroute="mysql01www";
   } elsif ( $hostname =~ /mysql02-db/ ) {
      $peerroute="mysql02";
   } elsif ( $hostname =~ /mysql01/ ) {
      $peerroute="galera";
   } elsif ( $hostname =~ /sisproxp0/ ) {
      $peerroute="sisproxprod";
   } elsif ( $hostname =~ /shib/ ) {
      $peerroute="shibprod";
   } elsif ( $hostname =~ /ritwebppl/ ) {
      $peerroute="people";
   } elsif ( substr($hostname,-3,3) =~ /0[1|2][a|b|c|d]/ ) {
      $peerroute=substr($hostname,0,-3);
   } elsif ( substr($hostname,-1,1) =~ /[a|b|c|d]/ ) {
      $peerroute=substr($hostname,0,-1);
   }

   print OUT "\n";
   if ( $peerip =~ /:/ ) {
      $tmp=`grep ' prefix-list ' /etc/frr/frr.conf | grep '/32' | awk '{printf \$7"\\n"}' | sort -u`;
      chomp($tmp);
      @prefix=split('\n',$tmp);
      foreach $prefix ( @prefix ) {
         print OUT "set policy-options prefix-list ${peerroute}_v6 ${prefix}\n";
      }

      print OUT "set policy-options policy-statement ${peerroute}-routes_v6 term get-routes from prefix-list ${peerroute}_v6\n";
      print OUT "set policy-options policy-statement ${peerroute}-routes_v6 term get-routes then accept\n";
      print OUT "set policy-options policy-statement ${peerroute}-routes_v6 term default_deny then reject\n";

      print OUT "\n";
      print OUT "set protocols bgp group ebgp6_systems neighbor ${peerip} description ${peerroute}\n";
      print OUT "set protocols bgp group ebgp6_systems neighbor ${peerip} import ${peerroute}-routes_v6\n";
      print OUT "set protocols bgp group ebgp6_systems neighbor ${peerip} authentication-key ${peerpw}\n";
   } else {
      $tmp=`grep ' prefix-list ' /etc/frr/frr.conf | grep '/32' | awk '{printf \$7"\\n"}' | sort -u`;
      chomp($tmp);
      @prefix=split('\n',$tmp);

      foreach $prefix ( @prefix ) {
         print OUT "set policy-options prefix-list ${peerroute} ${prefix}\n";
      }

      print OUT "set policy-options policy-statement ${peerroute}-routes term get-routes from prefix-list ${peerroute}\n";
      print OUT "set policy-options policy-statement ${peerroute}-routes term get-routes then accept\n";
      print OUT "set policy-options policy-statement ${peerroute}-routes term default_deny then reject\n";

      print OUT "\n";
      print OUT "set protocols bgp group ebgp_systems neighbor ${peerip} description ${hostname}\n";
      print OUT "set protocols bgp group ebgp_systems neighbor ${peerip} authentication-key ${peerpw}\n";
      print OUT "set protocols bgp group ebgp_systems neighbor ${peerip} import ${peerroute}-routes\n";
   }

   close(OUT);
}
close(IN);
