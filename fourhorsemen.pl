#!/usr/bin/perl

# Purpose: to flip out and apply modifications to Traveller
# .sec files to bring them up to date for 1248. It uses the
# alternate collapse rules from Stellar Reaches issue 5 as a
# starting point but includes a few fudges or shortcuts.
# This program is made available under the same terms as Perl 
# itself. Please see the README for more information. 

# last modified Tue  1 Apr 2008 12:28:01 BST

use strict;
use lib '/home/milo/bin/lib/perl5/site_perl/';
use Games::Dice 'roll';

# single sector data file 
# as input
unless (@ARGV)
{
	print "Usage: fourhorsemen.pl <sector_file> <class_file>\n";
	exit;
}
my $infile = $ARGV[0];
my $outfile = "$infile.out";
my $classfile = $ARGV[1];

# useful variables
my $ss_height  = 9; # subsect height

# set up the classification file first.
# this is an array of arrays that holds the info. on
# what sort of subsector a world is in (e.g. wilds).
my @regions;
open (CLASS,"<$classfile") or die "Can't open $classfile: $!";
my @lines = <CLASS>;
my $linecount = 0;
foreach my $line (@lines)
{
	chomp($line);
	my @parts = split(/,/,$line);
	my $start = 0 + $linecount;
	my $stop = $ss_height + $linecount;
	for (my $i=$start;$i<=$stop;$i++)
	{
		# fill from left to right
		for my $col1 (0..7) { $regions[$col1]->[$i] = $parts[0]; }
		for my $col2 (8..16) { $regions[$col2]->[$i] = $parts[1]; }
		for my $col3 (17..24) { $regions[$col3]->[$i] = $parts[2]; }
		for my $col4 (25..32) { $regions[$col4]->[$i] = $parts[3]; }
	}
	$linecount += 10;
}
close CLASS;


# read through each line, chop up and apply die rolls
open (SEC,">new_$infile") or die "Can't open new_$infile: $!"; # new sector data
open (NOTES,">notes_$infile") or die "Can't open notes_$infile: $!"; #anything interesting that happens
open (IN,"<$infile") or die "Can't open $infile: $!";
my $continue = 0;
my %secdata = ();
my %newera = ();

########################################
# make a hash of each line with sector #
# location being the key               #
########################################
my @lines = <IN>;
my $title = $lines[0];
foreach my $line (@lines)
{
	chomp $line;
	if ($line =~ /\.\.\.\.\+/)
	{
		$continue = 1;
		next;
	}
	next unless ($continue == 1);
	my $key = substr $line,14,4;
	$secdata{$key} = $line;
}
close IN;


########################################
# examine each world in the sector and #
# process it                           #
########################################
foreach my $key (sort {$a <=> $b} keys %secdata)
{
	# the various parts of the uwp
	# and associated data
	my $boneyard = 0;
	my $line = $secdata{$key};
	my $name = substr $line,0,14;
	my $hexnbr = substr $line,14,4;
	my $uwp = substr $line,19,10;
	my $bases = substr $line,30,1;
	my $codeandcomment = substr $line,32,14;
	my $zone = substr $line,49,1;
	my $pbg = substr $line,51,3;
	my $allegiance = substr $line,55,2;
	my $stellardata = substr $line,58,15;

	# a gratuitous message
	my $status = "$hexnbr $name $uwp";
	$status =~ s/\s+$//;
	print $status;

	# three parts of pbg
	my ($popmult,$belts,$gasgiants) = split(/|/,$pbg);

	# determine subsector of hex, which determines
	# the modifiers to apply
	my $row = (substr $hexnbr,0,2) - 1;
	my $column = (substr $hexnbr,2,2) - 1;
	my $ss_code = $regions[$row]->[$column];

	# I assumed that one won't find alliances except in safe and frontier
	$allegiance = "Na" unless ($ss_code =~ /[SF]/);


	# individual parts of uwp split for manipulation
	# must re-assemble it later for printing
	my $tmpuwp = $uwp;
	$tmpuwp =~ s/-//;
	my ($port,$size,$atmos,$hydro,$pop,$gov,$law,$tl) = split(/|/,$tmpuwp);
	my $origtl = $tl;
	my $origpop = $pop;	
	my $origgov = $gov;
	my $origlaw = $law;
	my $origport = $port;
	my $origbases = $bases;

	# print out some notes to then notes page
	print NOTES "$hexnbr $ss_code\t$name\t$uwp\n";

	################################
	# start applying the modifiers #
	################################
	
	########################
	# atmospheric collapse #
	########################
	my $roll = roll '2d6';
	if ($ss_code eq 'W') { $roll += 1; }
	elsif ($ss_code eq 'D') { $roll += 2; }
	elsif ($ss_code eq 'H') { $roll += 3; }
	if ($port eq 'A')  { $roll += 1; }
	if ($pop > 8)  { $roll += 1; }
	my $origatmos = $atmos;
	if ($roll >= 14)
	{
		$roll = roll '2d6';
		if  ($ss_code eq 'D' or $ss_code eq 'H' ) { $roll += 2; }
		if ($roll <= 8 and ($atmos == 5 or $atmos == 6 or $atmos == 8))
		{
			if ($atmos == 5) { $atmos = 4; }
			elsif ($atmos == 6) { $atmos = 7; }
			elsif ($atmos == 8) { $atmos = 9; }
			print NOTES "Atmospheric collapse: ";
			print NOTES "untainted ($origatmos) becomes tainted ($atmos).\n";
		}
		elsif ($roll >= 9 and $roll <= 10 and ($atmos == 5 or $atmos == 6 or $atmos == 8))
		{
			if ($atmos == 5) { $atmos = 4; }
			elsif ($atmos == 6) { $atmos = 7; }
			elsif ($atmos == 8) { $atmos = 9; }
			$pop = &adj_other($pop,-2);
			$tl = &adj_other($tl,-1);
			print NOTES "Atmospheric collapse: ";
			print NOTES "untainted ($origatmos) becomes tainted ($atmos), pop. & TL reduced.\n";
		}
		elsif ($roll == 11 or $roll == 12)
		{
			$atmos = "C";
			$pop = &adj_other($pop,-2);
			$tl = &adj_other($tl,-2);
			print NOTES "Atmospheric collapse: ";
			print NOTES "atmosphere becomes insidious, pop. & TL reduced.\n";
		}
		elsif ($roll >= 13)
		{
			print NOTES "Atmospheric collapse: ";
			print NOTES "atmosphere becomes insidious, world boneyarded.\n";
			$tl = 0;
			$pop = 0;
			$popmult = 0;
			$law = 0;
			$gov = 0;
			$port = "X";
			$bases = "R" if ($bases =~ /\S+/);
			$boneyard = 1;
		}
		if ($pop == 0)
		{
			print NOTES "Population dies off, world boneyarded.\n";
			$tl = 0;
			$pop = 0;
			$popmult = 0;
			$law = 0;
			$gov = 0;
			$port = "X";
			$bases = "R" if ($bases =~ /\S+/);
			$boneyard = 1;
		}

	}

	#####################
	# collapse starport #
	#####################
	unless ($boneyard == 1)
	{
		$roll = roll '1d6';
		if ($ss_code eq "S") { $roll -= 2; }
		elsif ($ss_code eq "W") { $roll += 2; }
		elsif ($ss_code eq "D") { $roll += 3; }
		elsif ($ss_code eq "H") { $roll += 4; }
		if ($pop <= 2) { $roll += 4; }
		elsif ($pop == 3 or $pop == 4) { $roll += 2; }
		if ($tl <= 4 )  { $roll += 5; }
		elsif ($tl == 5  or $tl == 6)  { $roll += 3; }
		elsif ($tl == 9  )  { $roll -= 1; }
		elsif ($tl eq "A" ) { $roll -= 1; }
		elsif ($tl =~ /[B-F]/)  { $roll -= 2; }
		if ($port eq 'A')  { $roll += 2; } 
		elsif ($port eq 'B')  { $roll += 1; } 
		elsif ($port eq 'D')  { $roll -= 2; } 

		if ($roll == 5 or $roll == 6)
		{
			$port = &adj_port($port,-1);
			$pop = &adj_other($pop,-1);
			$tl = &adj_other($tl,-1);
		}
		elsif ($roll == 7 or $roll == 8)
		{
			$port = &adj_port($port,-2);
			$pop = &adj_other($pop,-1);
			$tl = &adj_other($tl,-3);
		}
		elsif ($roll == 9 or $roll == 10)
		{
			$port = &adj_port($port,-3);
			$pop = &adj_other($pop,-2);
			$tl = &adj_other($tl,-5);
		}
		elsif ($roll >= 11)
		{
			$port = &adj_port($port,-4);
			$pop = &adj_other($pop,-2);
			$tl = &adj_other($tl,-7);
		}
	}

	###############
	# collapse TL #
	###############
	unless ($boneyard == 1)
	{
		my $drop = 0;
		$roll = roll '1d6';
		if ($ss_code eq "S") { $roll -= 3; }
		elsif ($ss_code eq "F") { $roll -= 1; }
		elsif ($ss_code eq "D") { $roll += 1; }
		elsif ($ss_code eq "H") { $roll += 3; }
		if ($pop <= 5) { $roll += 1; }
		if ($tl <= 4 )  { $roll -= 2; }
		elsif ($tl == 9  )  { $roll += 2; }
		elsif ($tl eq "A" ) { $roll += 2; }
		elsif ($tl =~ /[B-D]/)  { $roll += 4; }
		elsif ($tl =~ /[E-F]/)  { $roll += 6; }
		if ($port eq 'A')  { $roll -= 2; } 
		elsif ($port eq 'B')  { $roll -= 1; } 
		elsif ($port eq 'E' or $port eq 'X')  { $roll += 1; } 
		if ($atmos <= 3)  { $roll += 1; } 
		elsif ($atmos eq 'A' or $atmos eq 'B' )  { $roll += 1; } 
		elsif ($atmos eq 'C')  { $roll += 2; } 
		if ($hydro <= 1) { $roll += 1; } 
		elsif ($hydro eq 'A') { $roll += 1; } 
		
		if ($roll == 5 or $roll == 6)
		{
			$drop = roll '1d6-3';
			if ($drop < 0) { $drop = 0; }
			$tl = &adj_other($tl,-$drop);
		}
		elsif ($roll == 7 or $roll == 8)
		{
			$drop = roll '1d6';
			$tl = &adj_other($tl,-$drop);
		}
		elsif ($roll == 9 or $roll == 10)
		{
			$drop = roll '2d6';
			$tl = &adj_other($tl,-$drop);
		}
		elsif ($roll >= 11)
		{
			$drop = roll '3d6';
			$tl = &adj_other($tl,-$drop);
		}

		# check that world can survive
		# with current TL and atmosphere
		if (&techcheck($tl,$atmos) != 0)
		{
			$tl = 0;
			$pop = 0;
			$popmult = 0;
			$law = 0;
			$gov = 0;
			$port = "X";
			$bases = "R" if ($bases =~ /\S+/);
			$boneyard = 1;
			print NOTES "Boneyarded due to insufficient TL for atmosphere.\n";
		}
	}

	#######################
	# collapse population #
	#######################
	unless ($boneyard == 1)
	{
		$roll = roll '1d6';
		if ($ss_code eq 'S') { $roll -= 6; }
		elsif ($ss_code eq 'F') { $roll -= 2; }
		elsif ($ss_code eq 'D') { $roll += 2; }
		elsif ($ss_code eq 'H') { $roll += 4; }
		if ($size < 3)  { $roll += 2; }
		if ($atmos < 4 or $atmos eq 'B')  { $roll += 6; }
		if ($atmos == 5 )  { $roll -= 2; }
		if ($atmos == 6 or $atmos == 8)  { $roll -= 6; }
		if ($atmos eq 'A')  { $roll += 4; }
		if ($atmos eq 'C')  { $roll += 8; }
		if ($hydro < 3) { $roll += 4; }

		# N.B. I will add the re-rolling of the population
		# mutliplier when I can check what the roll is
		if ($roll == 5 or $roll == 6)
		{
			$pop -= 1;
			$popmult = roll '1d9';
		}
		if ($roll == 7 or $roll == 8) { $pop -= 2; $popmult = roll '1d9'; }
		if ($roll == 9 or $roll == 10) { $pop -= 3; $popmult = roll '1d9'; }
		if ($roll == 11 or $roll == 12) { $pop -= 4; $popmult = roll '1d9'; }
		if ($roll == 13 or $roll == 14) { $pop -= 5; $popmult = roll '1d9'; }
		if ($roll == 15 or $roll == 16) { $pop -= 6; $popmult = roll '1d9'; }
		if ($roll == 17 or $roll == 18) { $pop -= 7; $popmult = roll '1d9'; }
		if ($roll >= 19) { $pop -= 8; $popmult = roll '1d9'; }

		if ($pop < 1)
		{
			$tl = 0;
			$pop = 0;
			$popmult = 0;
			$law = 0;
			$gov = 0;
			$port = "X";
			$bases = "R" if ($bases =~ /\S+/);
			$boneyard = 1;
			print NOTES "Boneyarded due to population collapse.\n";
		}
	}

	#######################
	# collapse government #
	#######################
	unless ($boneyard == 1)
	{
		$roll = roll '2d6';
		if ($ss_code eq 'S') { $roll -= 3; }
		elsif ($ss_code eq 'F') { $roll -= 1; }
		elsif ($ss_code eq 'D') { $roll += 1; }
		elsif ($ss_code eq 'H') { $roll += 3; }
		if ($pop < $origpop) { $roll += ($pop - $origpop); }

		if ($roll >= 7 and $roll <= 9)
		{
			# central government collapses (huzzah!)
			if ($pop >= 2) { $gov = 7; }
			else { $gov = 0; }
			print NOTES "Central government collapses.\n";
		}
		elsif ($roll >= 10)
		{
			# government is replaced
			$roll = roll '2d6';
			if ($ss_code eq 'S') { $roll -= 2; }
			elsif ($ss_code eq 'F') { $roll -= 1; }
			elsif ($ss_code eq 'D') { $roll += 1; }
			elsif ($ss_code eq 'H') { $roll += 3; }
			if ($roll <= 1) { $gov = 'Q'; }
			elsif ($roll == 2) { $gov = 'C'; }
			elsif ($roll == 3) { $gov = '5'; }
			elsif ($roll == 4) { $gov = '0'; }
			elsif ($roll == 5) { $gov = 'A'; }
			elsif ($roll == 6) { $gov = 'M'; }
			elsif ($roll == 7) { $gov = '7'; }
			elsif ($roll == 8) { $gov = 'T'; }
			elsif ($roll == 9) { $gov = '6'; }
			elsif ($roll == 10) { $gov = '1'; }
			elsif ($roll == 11) { $gov = 'D'; }
			elsif ($roll == 12) { $gov = 'B'; }
			elsif ($roll == 13) { $gov = 'S'; }
			elsif ($roll > 13) { $gov = 'V'; }
			print NOTES "Government changes from $origgov to $gov.\n"
		}
	}

	######################
	# collapse law level #
	######################
	unless ($boneyard == 1)
	{
		$roll = roll '2d6-7';
		my $baselaw = 0;
		if ($gov eq '0')
		{
			$law = 0;
		}
		else
		{
			if ($gov == 1) { $baselaw = 2; }
			elsif ($gov == 5) { $baselaw = 5; }
			elsif ($gov == 6) { $baselaw = 9; }
			elsif ($gov eq 'A') { $baselaw = 11; }
			elsif ($gov eq 'B') { $baselaw = 10; }
			elsif ($gov eq 'C') { $baselaw = 11; }
			elsif ($gov eq 'Q') { $baselaw = 7; }
			elsif ($gov eq 'M') { $baselaw = 12; }
			elsif ($gov eq 'S') { $baselaw = 11; }
			elsif ($gov eq 'T') { $baselaw = 13; }
			elsif ($gov eq 'V') { $baselaw = 15; }
			else
			{
				if ($gov =~ /A-Z/) { $baselaw = 'A'; } # Oh no, a fudge!
				else { $baselaw = $gov; }
			}
			my $tlaw = $baselaw + $roll;
			if ($tlaw < 0 ) { $tlaw = 0; }
			if ($tlaw > &convert($origlaw))
			{
				$law = &convert($tlaw);
				print NOTES "Harsh laws enacted ($origlaw->$law).\n";
			}
			elsif  ($law < &convert($origlaw))
			{
				$law = &convert($tlaw);
				print NOTES "Laws relaxed/collapsed ($origlaw->$law).\n";
			}
		}
	}

	##################
	# collapse bases #
	##################
	unless ($boneyard == 1)
	{
		if ($bases =~ /\S+/)
		{
			if ($port eq 'X' or (&convert($port)-&convert($origport) > 1))
			{
				$bases = 'R';
			}	
			else
			{
				$roll = roll '2d6';
				if ($ss_code eq 'S') { $roll -= 8; }
				elsif ($ss_code eq 'F') { $roll -= 4; }
				elsif ($ss_code eq 'D') { $roll += 2; }
				elsif ($ss_code eq 'H') { $roll += 4; }
				if ($bases =~ /[BA]/) { $roll += 2; }
				elsif ($bases eq 'N') { $roll += 1; }
				else { $roll += 4; }
				if ($roll >= 6) { $bases = "R"; }
			}
		}
	}

	##########################
	# random collapse events #
	##########################
	unless ($boneyard == 1)
	{
		my $num_events = 0;
		my %eventseen = ();
		$roll = roll '1d10';
		if ($roll == 3 or $roll == 4) { $num_events = 1; }
		elsif ($roll> 4) { $num_events = roll '1d3'; }
		for (my $i=1; $i<=$num_events; $i++)
		{
			# roll on the random collapse events results table!
			# I fudge this to avoid rolling the same thing twice
			$roll = roll '1d10';
			next if $eventseen{$roll} == 1;
			if ($roll == 1) 
			{ 
				$gov = 'V';
				my $lawroll = roll '2d6+8';
				$law = &convert($lawroll);
				print NOTES "Severe virus infection.\n";
			}
			if ($roll == 2) 
			{ 
				if ($port eq 'A') { $port = 'B'; }
				elsif ($port eq 'B') { $port = 'C'; }
				print NOTES "Suffered excessive raids.\n";
			}
			if ($roll == 3) 
			{ 
				my $newlaw = &convert($law);
				$newlaw += roll '1d6';
				$law = &convert($newlaw);
				print NOTES "Major social catastrophe; law increases to $law.\n";
			}
			if ($roll == 4) 
			{ 
				$popmult -= roll '1d8+1';
				if ($popmult < 1)
				{
					$pop = &convert($pop) - 1;
					$popmult = $popmult + 10;
					if ($popmult >= 10) { $popmult = 9; }
					if ($popmult <= 0) { $popmult = 1; }
					if ($pop < 0) { $pop = 0; }
					print NOTES "Plague or bioweapon.\n";	
				}
			}
			if ($roll == 5) 
			{ 
				unless ($ss_code eq 'S')
				{
					print NOTES "Boneyarded by massive bombardment.\n";
					$tl = 0;
					$pop = 0;
					$popmult = 0;
					$law = 0;
					$gov = 0;
					$port = "X";
					$bases = "R";
					$boneyard = 1;
					last;
				}
			}
			if ($roll == 6) 
			{ 
				my $newtl = &convert($tl) + roll '1d3';
				if ($newtl > &convert($origtl))
				{
					$tl = $origtl;
				}
				else
				{
					$tl = &convert($newtl);
				}
				print NOTES "Undiscovered tech cache on world.\n";
			}
			if ($roll == 7) 
			{ 
				my $conq = roll '1d6';
				my $villain = "";
				if ($conq <=3) 
				{ 
					$gov = 6; 
					$law = &convert(roll '2d6+2'); 
					$villain = "pocket empire"
				}
				else 
				{ 
					$gov = 'S'; 
					$law = &convert(roll '2d6+4'); 
					$villain = "vampires"; 
				}	
				print NOTES "World conquered by $villain.\n";
			}
			if ($roll == 8) 
			{ 
				my $up = roll '1d3';
				$law = &convert(&convert($law) + $up);
				$pop = &convert(&convert($pop) - 1);
				if ($pop < 0) { $pop = 0; }
				print NOTES "Very harsh survival measures; law increases by $up.\n";
			}
			if ($roll == 9) 
			{ 
				$popmult = roll '1d9';
				$pop = &convert(&convert($pop) - 1);
				if ($pop < 0) { $pop = 0; }
				$tl = &convert(&convert($tl) - 1);
				print NOTES "False start.\n"
			}
			if ($roll == 10) 
			{ 
				print NOTES "Anomaly or no effect (collapse)\n";
			}
			$eventseen{$roll} = 1;
		}

	}

	#############
	# RECOVERY! #
	#############

	######################
	# recover population #
	######################
	if ($boneyard == 1)
	{
		# recovery through colonisation
		$roll = roll '1d6';
		if ($ss_code eq "S") { $roll += 2; }
		elsif ($ss_code eq "W") { $roll += 1; }
		elsif ($ss_code eq "D") { $roll -= 4; }
		elsif ($ss_code eq "H") { $roll -= 8; }
		if (&convert($atmos < 4) or &convert($atmos) > 9) { $roll -= 2; }
		elsif ($atmos == 5)  { $roll += 1; }
		elsif ($atmos == 6 or $atmos == 8)  { $roll += 2; }
		if ($origport eq 'A') { $roll += 2; }
		elsif ($origport eq 'B' or $origport eq 'C') { $roll += 1; }
		elsif ($origport eq 'E' or $port eq 'X') { $roll += 1; }
		if (&convert($origtl < 9))  { $roll -= 2; }
		elsif (&convert($origtl >= 11) and &convert($origtl <= 13))  { $roll += 1; }
		elsif (&convert($origtl >= 14))  { $roll += 2; }
		unless ($gasgiants > 0) { $roll -= 1; }

		# bases
		if ($origbases eq 'N' or $bases eq 'R') { $roll += 2; }
		elsif ($origbases eq 'S')  { $roll += 1; }
		elsif ($origbases eq 'B')  { $roll += 4; }

		# a fudge factor must be added here for
		# TL9 worlds in the vicinity. I can't think of one,
		# so at present I leave this to be checked by the ref

		if ($roll == 5 or $roll == 6)
		{
			print NOTES "Recolonised: advance station.\n";
			$pop = 1;
			$boneyard = 0;
		}
		elsif ($roll == 7 or $roll == 8)
		{
			print NOTES "Recolonised: station.\n";
			$pop = 2;
			$boneyard = 0;
		}
		elsif ($roll == 9 or $roll == 10)
		{
			print NOTES "Recolonised: base.\n";
			$pop = 3;
			$boneyard = 0;
		}
		elsif ($roll >= 11)
		{
			print NOTES "Recolonised: colony.\n";
			$pop = 4;
			$boneyard = 0;
		}

		# other modifications from the re-colonisation
		if ($boneyard == 0)
		{
			print NOTES "CHECK: roll was $roll.\n";
			$popmult = roll '1d9';
			$port = 'D';
			$gov = 6;
			$law = &convert(roll '2d6+2');
			$tl = roll '1d6';
			if ($size < 2) { $tl += 2; }
			elsif ($size > 1 and $size < 5) { $tl += 1; }
			if (&convert($atmos) < 4 or &convert($atmos) > 9)  { $tl += 1; }
			if ($hydro == 9 )  { $tl += 1; }
			elsif ($hydro eq 'A' )  { $tl += 2; }
			if ($pop > 0 and $pop < 5)  { $tl += 1; }
			elsif ($pop == 9)  { $tl += 2; }
			elsif ($pop eq 'A')  { $tl += 4; }
			my $mintech = &techcheck($tl,$atmos);
			if ($mintech != 0) { $tl = $mintech; }
		}
	}
	else
	{
		# standard population recovery
		$roll = roll '1d6';
		if ($ss_code eq "S") { $roll += 2; }
		elsif ($ss_code eq "W") { $roll += 1; }
		elsif ($ss_code eq "D") { $roll -= 2; }
		elsif ($ss_code eq "H") { $roll -= 4; }
		if (&convert($atmos < 4) or &convert($atmos) > 9) { $roll -= 1; }
		elsif ($atmos == 5)  { $roll += 1; }
		elsif ($atmos == 6 or $atmos == 8)  { $roll += 2; }
		if ($port eq 'A') { $roll += 2; }
		elsif ($port eq 'B') { $roll += 1; }
		elsif ($port eq 'E' or $port eq 'X') { $roll += 1; }

		if ($roll == 5 or $roll == 6)
		{
			$pop = &convert($pop + 1);
			print NOTES "Population recovers by 1.\n"
		}
		elsif ($roll >= 7)
		{
			$pop = &convert($pop) + 2;
			print NOTES "Population recovers by 2.\n"
		}
		if ($pop >= 10) { $pop = 'A'; }
	}


	####################
	# recover starport #
	####################
	unless ($boneyard == 1 or $pop == 0)
	{
		$roll = roll '2d6';
		if ($ss_code eq 'S') { $roll += 2; }
		elsif ($ss_code eq 'F') { $roll += 1; }
		elsif ($ss_code eq 'D') { $roll -= 2; }
		elsif ($ss_code eq 'H') { $roll -= 4; }
		my $tpop = &convert($pop);
		if ($tpop == 1) { $roll -= 2; }
		elsif ($tpop == 2) { $roll -= 1; }
		elsif ($tpop >= 6 and $pop <= 8) { $roll += 1; }
		elsif ($tpop >= 9) { $roll += 2; }
		my $ttl = &convert($tl);
		if ($ttl <= 8) { $roll -= 2; }
		elsif ($ttl == 12 or $ttl == 13) { $roll += 1; }
		elsif ($ttl > 13) { $roll += 1; }
		if ($port eq 'X')  { $roll -= 2; }

		if ($roll >= 5 and $roll <= 8) 
		{ 
			$port = &adj_port($port,1); 
			print NOTES "Port recovers to $port.\n";
		}
		elsif ($roll >= 5 and $roll <= 8) 
		{ 
			$port = &adj_port($port,1); 
			print NOTES "Port recovers to $port.\n";
		}
		elsif ($roll == 9  or $roll == 10) 
		{ 
			$port = &adj_port($port,2); 
			print NOTES "Port recovers to $port.\n";
		}
		elsif ($roll > 10) 
		{ 
			$port = &adj_port($port,2);
			$tl = &adj_other($tl,1);
			print NOTES "Port recovers to $port, TL increases to $tl.\n";
		}
	}

	######################
	# recover tech level #
	######################
	unless ($boneyard == 1)
	{
		$roll = roll '1d6';
		if ($ss_code eq 'S') { $roll += 2; }
		elsif ($ss_code eq 'F') { $roll += 1; }
		elsif ($ss_code eq 'D') { $roll -= 2; }
		elsif ($ss_code eq 'H') { $roll -= 6; }
		if ($atmos == 5) { $roll += 1; }
		elsif ($atmos == 6 or $atmos == 8) { $roll += 2; }
		my $tpop = &convert($pop);
		if ($tpop >= 0 and $tpop <= 3) { $roll -= 1; }
		elsif ($tpop >= 7 and $tpop <= 8) { $roll += 1; }
		elsif ($tpop >= 9) { $roll += 2; }
		if (&convert($law) >= 11)  { $roll -= 1; }
		if ($port eq 'A')  { $roll += 2; }
		elsif ($port eq 'B')  { $roll += 1; }
		elsif ($port eq 'E' or $port eq 'X' )  { $roll -= 4; }
		if ($bases =~ /[NAB]/)  { $roll += 2; }
		elsif ($bases =~ /[SM]/)  { $roll += 1; }

		my $ttl = &convert($tl);
		if ($roll >= 5 and $roll <= 6) { $ttl += 1; }
		elsif ($roll >= 7 and $roll <= 8) { $ttl += roll '1d3'; }
		elsif ($roll >= 9 and $roll <= 10) { $ttl += roll '1d3+1'; }
		elsif ($roll >= 11) { $ttl += roll '1d3+2'; }

		if (&convert($origtl) > 9)
		{
			if ($ttl > ($origtl + 1)) { $tl = &convert($origtl + 1); }
			else { $tl = &convert($ttl); }
		}
		else
		{
			if ($ttl > 9) { $tl = 9; }
			else { $tl = $ttl; }
		}
		if ($roll > 4) { print NOTES "TL increased to $tl (orig. was $origtl).\n"; }
	}

	######################
	# recover atmosphere #
	######################
	unless ($boneyard == 1)
	{
		if (&convert($tl) > 10)
		{
			$roll = roll '2d6';
			if ($ss_code eq 'D') { $roll -= 2; }
			elsif ($ss_code eq 'H') { $roll -= 2; }
			if (&convert($tl) > 15 and $atmos eq 'C' and $roll > 11)
			{
				my $recover = roll '2D6-7';					
				$recover += &convert($size);
				if ($recover <= 4) { $atmos = 4; }
				elsif ($recover >= 4 and $recover <= 8) { $atmos = 7; }
				elsif ($recover >= 9) { $atmos = 7; }
				print NOTES "Insidious atmosphere cleaned up.\n";
			}
			if ($roll > 10 and &convert($tl) > 10)
			{
				my $change = 0;
				if ($atmos == 4) { $atmos = 5; $change = 1; }
				elsif ($atmos == 7) { $atmos = 6; $change = 1; }
				elsif ($atmos == 9) { $atmos = 8; $change = 1; }
				print NOTES "Atmospheric taint cleaned.\n" if ($change == 1);
			}
		}	
	}

	######################
	# recover government #
	######################
	my $curgov = $gov;			
	unless ($boneyard == 1)
	{
		$roll = roll '2d6';
		if ($ss_code eq 'S') { $roll += 3; }
		elsif ($ss_code eq 'F') { $roll += 1; }
		elsif ($ss_code eq 'D') { $roll -= 1; }
		elsif ($ss_code eq 'H') { $roll -= 3; }
		$roll += abs(&convert($origpop) - &convert($pop));

		if ($roll >= 7 and $roll <=9)
		{
			# roll on the post-collapse government table
			$roll = roll '2d6';
			if ($ss_code eq 'S') { $roll -= 2; }
			elsif ($ss_code eq 'F') { $roll -= 1; }
			elsif ($ss_code eq 'D') { $roll += 1; }
			elsif ($ss_code eq 'H') { $roll += 3; }
			if ($roll <= 1) { $gov = 'Q'; }
			elsif ($roll == 2) { $gov = 'C'; }
			elsif ($roll == 3) { $gov = '5'; }
			elsif ($roll == 4) { $gov = '0'; }
			elsif ($roll == 5) { $gov = 'A'; }
			elsif ($roll == 6) { $gov = 'M'; }
			elsif ($roll == 7) { $gov = '7'; }
			elsif ($roll == 8) { $gov = 'T'; }
			elsif ($roll == 9) { $gov = '6'; }
			elsif ($roll == 10) { $gov = '1'; }
			elsif ($roll == 11) { $gov = 'D'; }
			elsif ($roll == 12) { $gov = 'B'; }
			elsif ($roll == 13) { $gov = 'S'; }
			elsif ($roll > 13) { $gov = 'V'; }
			print NOTES "Government $curgov replaced with $gov during reconstruction.\n";
		}
		elsif ($roll >= 10)
		{
			# roll on standard Traveller government table
			my $tempgov = roll '2d6-7'; 
			$tempgov += &convert($pop);
			$tempgov = 0 if ($tempgov < 0);
			$gov = &convert($tempgov);
			print NOTES "Government $curgov replaced with $gov during reconstruction.\n";
		}

	}

	#####################
	# recover law level #
	#####################
	my $curlaw = $law;
	unless ($boneyard == 1)
	{
		if (&convert($curgov) != &convert($gov))
		{
			$roll = roll '2d6-7';
			my $baselaw;
			if ($gov eq '0')
			{
				$law = 0;
			}
			else
			{
				if ($gov == 1) { $baselaw = 2; }
				elsif ($gov == 5) { $baselaw = 5; }
				elsif ($gov == 6) { $baselaw = 9; }
				elsif ($gov eq 'A') { $baselaw = 11; }
				elsif ($gov eq 'B') { $baselaw = 10; }
				elsif ($gov eq 'C') { $baselaw = 11; }
				elsif ($gov eq 'Q') { $baselaw = 7; }
				elsif ($gov eq 'M') { $baselaw = 12; }
				elsif ($gov eq 'S') { $baselaw = 11; }
				elsif ($gov eq 'T') { $baselaw = 13; }
				elsif ($gov eq 'V') { $baselaw = 15; }
				else
				{
					if ($gov =~ /A-Z/) { $baselaw = 'A'; } # Oh no, a fudge!
					else { $baselaw = $gov; }
				}
			}
			$law = $baselaw + $roll;
			if ($law < 0 ) { $law = 0; }
			if (&convert($gov) == 0 ) { $law = 0; }
			if ($law > &convert($curlaw))
			{
				$law = &convert($law);
				print NOTES "Harsh laws enacted ($curlaw->$law).\n";
			}
			elsif  ($law < &convert($curlaw))
			{
				$law = &convert($law);
				print NOTES "Laws relaxed/collapsed ($curlaw->$law).\n";
			}
		}
	}

	#################################################
	# create new trade classifications &c.          #
	# Taken from MT ref's manual - check against CT #
	#################################################
	my @tradeclass = ();
	my $bar = 0;
	if ((&convert($atmos) >= 4 and &convert($atmos) <= 9) and (&convert($hydro) >= 4 and &convert($hydro) <= 8) and (&convert($pop) >= 5 and &convert($pop) <= 7)) 
	{ 
		push(@tradeclass,"Ag");
	}
	if (&convert($size) == 0 and &convert($atmos) == 0 and &convert($hydro) == 0) 
	{ 
		push(@tradeclass,"As");
	}
	if (&convert($pop) == 0 and &convert($gov) == 0 and &convert($law) == 0) 
	{ 
		push(@tradeclass,"Ba");
		$bar = 1;
	}
	if (&convert($atmos) >= 2 and &convert($hydro) == 0) 
	{ 
		push(@tradeclass,"De");
	}
	if (&convert($size) >= 10 and &convert($atmos) >= 1) 
	{ 
		push(@tradeclass,"Fl");
	}
	if (&convert($pop) >= 9) 
	{ 
		push(@tradeclass,"Hi");
	}
	if ((&convert($atmos) == 0 or &convert($atmos) == 1) and &convert($hydro) > 0) 
	{ 
		push(@tradeclass,"Ic");
	}
	if (((&convert($atmos) >= 2 and &convert($atmos) <= 4) or &convert($atmos == 7) or &convert($atmos == 9)) and &convert($pop) > 8) 
	{ 
		push(@tradeclass,"In");
	}
	if (&convert($pop) <= 3 and &convert($pop) > 0)
	{
		push(@tradeclass,"Lo") unless ($bar == 1);	
	}
	if ((&convert($atmos) >= 0 and &convert($atmos) <= 3) and (&convert($hydro) >= 0 and &convert($hydro) <= 3) and &convert($pop) >= 6) 
	{ 
		push(@tradeclass,"Na");
	}
	if (&convert($pop) >= 0 and &convert($pop) <= 6)
	{
		push(@tradeclass,"Ni") unless ($bar == 1);	
	}
	if ((&convert($atmos) >= 2 and &convert($atmos) <= 5) and (&convert($hydro) >= 0 and &convert($hydro) <= 3))
	{
		push(@tradeclass,"Po") unless ($bar == 1);	
	}
	if ((&convert($atmos) == 6 or &convert($atmos) == 8) and (&convert($pop) >= 6 and &convert($pop) <= 8) and (&convert($gov) >= 4 and &convert($gov) <= 9))
	{
		push(@tradeclass,"Ri");	
	}
	if (&convert($atmos) == 0)
	{
		push(@tradeclass,"Va");	
	}
	if (&convert($hydro) > 9)
	{
		push(@tradeclass,"Wa");	
	}
	my $tcode = join(" ",@tradeclass);

	#################
	# recover bases #
	#################
	unless ($boneyard == 1)
	{
		my $mods = 0;
		my $military = 0;
		my $navy = 0;
		my $pirate = 0;
		my $scout = 0;
		my $trade = 0;
		if ($ss_code eq 'F') { $mods -= 1; }
		elsif ($ss_code eq 'W') { $mods -= 2; }
		elsif ($ss_code eq 'D') { $mods -= 3; }
		elsif ($ss_code eq 'H') { $mods -= 4; }

		# military bases
    $roll = roll '2d6' + $mods;
		if ($port eq 'B') { $roll += 1; }
		elsif ($port eq 'C') { $roll += 2; }
		$military = 1 if ($roll >= 10);
		# naval bases
    $roll = roll '2d6' + $mods;
		$navy = 1 if ($roll >= 8);
		# pirate bases
    $roll = roll '2d6' + $mods;
		if ($port eq 'B') { $roll += 1; }
		elsif ($port eq 'C') { $roll += 2; }
		elsif ($port eq 'D') { $roll += 3; }
		elsif ($port eq 'E') { $roll += 4; }
		elsif ($port eq 'X') { $roll += 5; }
		if ($navy == 1) { $roll -= 2; }
		$pirate = 1 if ($roll >= 11);
		# scout bases
    $roll = roll '2d6' + $mods;
		if ($port eq 'A') { $roll -= 3; }
		elsif ($port eq 'B') { $roll -= 2; }
		elsif ($port eq 'C') { $roll -= 1; }
		$scout = 1 if ($roll >= 7);
		# trade bases
    $roll = roll '2d6' + $mods;
		if ($tl <= 6) { $roll -= 4; }
		$trade = 1 if ($roll >= 11);
		
		if (grep "Ag",@tradeclass) { $roll += 1; }
		if (grep "In",@tradeclass) { $roll += 1; }
		if (grep "Ri",@tradeclass) { $roll -= 1; }
		if (grep "Na",@tradeclass) { $roll -= 1; }
		if (grep "Ni",@tradeclass) { $roll -= 1; }
		if (grep "Po",@tradeclass) { $roll -= 1; }
		if ($port eq 'C') { $roll += 2; }
		elsif ($port eq 'D') { $roll += 2; }
		if ($roll >= 11) { $trade = 1; }

		# remove un-needed bases
		$military = 0 if ($port =~ /[DEX]/);
		$military = 0 if ($scout == 1);
		$navy = 0 if ($port =~ /[CDEX]/);
		$pirate = 0 if ($scout == 1);
		$scout = 0 if ($port =~ /[EX]/);
		$scout = 0 if ($military == 1);
		$scout = 0 if ($pirate == 1);
		$trade = 0 if  ($port =~ /[ABX]/);
		$trade = 0 if ($ss_code eq 'S');


		# finally, generate the classification
		# N.B. not all classifications are covered here - the referee ought to 
		# decide about depots, way stations &c.
		if ($military == 0 and $navy == 1 and $pirate == 0 and $scout == 1 and $trade == 0) { $bases = "A"; }
		if ($military == 0 and $navy == 0 and $pirate == 1 and $scout == 0 and $trade == 0) { $bases = "C"; }
		if ($military == 1 and $navy == 1 and $pirate == 0 and $scout == 0 and $trade == 0) { $bases = "F"; }
		if ($military == 0 and $navy == 1 and $pirate == 1 and $scout == 0 and $trade == 0) { $bases = "H"; }
		if ($military == 1 and $navy == 0 and $pirate == 0 and $scout == 0 and $trade == 0) { $bases = "M"; }
		if ($military == 0 and $navy == 1 and $pirate == 0 and $scout == 0 and $trade == 0) { $bases = "N"; }
		if ($military == 0 and $navy == 0 and $pirate == 0 and $scout == 1 and $trade == 0) { $bases = "S"; }
		if ($military == 0 and $navy == 0 and $pirate == 0 and $scout == 0 and $trade == 1) { $bases = "T"; }
		if ($military == 1 and $navy == 0 and $pirate == 0 and $scout == 0 and $trade == 1) { $bases = "U"; }
		if (($military + $navy + $pirate + $scout + $trade) > 0) 
		{ 
			print NOTES "New base(s) established: $bases\n"; 
		}
	}

	##########################
	# random recovery events #
	##########################
	unless ($boneyard == 1)
	{
		my $num_events = 0;
		my %eventseen = ();
		$roll = roll '1d10';
		if ($roll == 3 or $roll == 4) { $num_events = 1; }
		elsif ($roll> 4) { $num_events = roll '1d3'; }
		for (my $i=1; $i<=$num_events; $i++)
		{
			# roll on the random collapse events results table!
			# I fudge this to avoid rolling the same thing twice
			$roll = roll '1d10';
			next if $eventseen{$roll} == 1;
			if ($roll == 1) 
			{ 
				if ($port eq 'A') { $port = 'B'; }
				elsif ($port eq 'B') { $port = 'C'; }
				print NOTES "Suffered excessive raids.\n";
			}
			if ($roll == 2) 
			{ 
				my $newtl = &convert($tl) + roll '1d3';
				unless ($newtl > &convert($origtl))
				{
					$tl = &convert($newtl);
				}
				print NOTES "Undiscovered tech cache on world.\n";
			}
			if ($roll == 3) 
			{ 
				my $conq = roll '1d6';
				my $villain = "";
				if ($conq <=3) 
				{ 
					$gov = 6; 
					$law = &convert(roll '2d6+2'); 
					$villain = "pocket empire"
				}
				else 
				{ 
					$gov = 'S'; 
					$law = &convert(roll '2d6+4'); 
					$villain = "vampires"; 
				}	
				print NOTES "World conquered by $villain.\n";
			}
			if ($roll == 4) 
			{ 
				my $up = roll '1d3';
				$law = &convert(&convert($law) + $up);
				$pop = &convert(&convert($pop) - 1);
				if ($pop < 0) { $pop = 0; }
				print NOTES "Very harsh survival measures; law increases by $up.\n";
			}
			if ($roll == 5) 
			{ 
				$popmult = roll '1d9';
				$pop = &convert(&convert($pop) - 1);
				if ($pop < 0) { $pop = 0; }
				$tl = &convert(&convert($tl) - 1);
				print NOTES "False start.\n"

			}
			if ($roll == 6) 
			{ 
				my $ttl = &convert($tl) - 1;	
				if ($ttl < 0) { $ttl = 0; }
				$tl = &convert($ttl);
				print NOTES "Recovery nearly got started.\n";
			}
			if ($roll == 7) 
			{ 
				my $newtl = &convert($tl) + 1;
				if ($newtl > (&convert($origtl) +1))
				{
					my $ttl = &convert($newtl) +1;
					$tl = &convert($ttl);
				}
				else
				{
					$tl = &convert($newtl);
				}
				my $newlaw = &convert($law);
				$newlaw -= roll '1d3';
				if ($newlaw < 0) { $newlaw = 0; }
				$law = &convert($newlaw);
				print NOTES "Population learned to pull together.\n";
			}
			if ($roll == 8) 
			{ 
				my $newpop = &convert($pop);
				$newpop += 1;
				if ($newpop > 10) { $newpop = 10; }
				$pop = &convert($newpop);
				my $newtl = &convert($tl) + roll '1d3'; 
				if ($newtl > (&convert($origtl) +1))
				{
					my $ttl = &convert($newtl) +1;
					$tl = &convert($ttl);
				}
				else
				{
					$tl = &convert($newtl);
				}
				if ($port eq 'X') { $port = 'D'; }
				else { $port = &adj_port($port,1); }
				print NOTES "Impressive recovery.\n";
			}
			if ($roll == 9) 
			{ 
				my $newpop = &convert($pop);
				$newpop += 1;
				if ($newpop > 10) { $newpop = 10; }
				$pop = &convert($newpop);
				my $newtl = &convert($tl) + roll '1d3'; 
				if ($newtl > (&convert($origtl) +1))
				{
					my $ttl = &convert($newtl) +1;
					$tl = &convert($ttl);
				}
				else
				{
					$tl = &convert($newtl);
				}
				if (&convert($tl) < 9) { $tl = 9; }
				if ($port eq 'X' or $port eq 'E') { $port = 'C'; }
				else { $port = &adj_port($port,1); }
				print NOTES "Amazing recovery.\n";
			}
			if ($roll == 10) 
			{ 
				print NOTES "Anomaly or no effect (recovery).\n";
			}
			$eventseen{$roll} = 1;
		}

	}

	###################
	# final uwp check #
	###################

	# make sure that the world can support itself
	unless ($boneyard == 1)
	{
		my $mintech = &techcheck($tl,$atmos);
		if ($mintech != 0) { $tl = $mintech; }
	}

	# other checks to be left to referee


	##############################
	# update hash with new stats #
	##############################

	# create a new uwp
	if (length($law) > 1) { $law = &convert($law); }
	my $newuwp = join("",$port,$size,$atmos,$hydro,$pop,$gov,$law);
	my $newtl = &adj_other($tl,0);
	$newuwp .= "-$newtl";

	# join results into hash
	my $output = sprintf '%-14s', $name;
	$output .=  sprintf '%-5s', $hexnbr;
	$output .=  sprintf '%-8s', $newuwp;
	$output .=  sprintf '%-1s', "  $bases";
	$output .=  sprintf '%-15s', " $tcode";
	$output .=  sprintf '%-1s', " $zone";
	$output .=  sprintf '%-3s', "   $popmult" . $belts . $gasgiants;
	$output .=  sprintf '%-2s', " $allegiance";
	$output .=  " $stellardata";

	$newera{$key} = $output;

	# print the final uwp to the notes 
	print " -> $newuwp\n";
	print NOTES "Final UWP: $newuwp\n";
	# divide notes sections with a nice dotted line
	print NOTES "----------\n";
}

#######################################
# print out the new sector data table #
#######################################
print SEC <<EOF;
$title
Modified for 1248 by "fourhorsemen.pl" (knirirr\@gmail.com)

The data in the sector text files is laid out in column format:

 1-14: Name
15-18: HexNbr
20-28: UWP
   31: Bases
33-47: Codes & Comments
   49: Zone
52-54: PBG
56-57: Allegiance
59-74: Stellar Data

....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
EOF
foreach my $key (sort {$a <=> $b} keys %newera)
{
	print SEC "$newera{$key}\n";
}
close SEC;
close NOTES;

print "Finished!\n";

###############################
# various important functions #
###############################

# alter starport values
sub adj_port
{
	my $val = shift;
	my $amt = shift;

	my %ports = ("A" => 5,
							 "B" => 4,
							 "C" => 3,
							 "D" => 2,
							 "E" => 1,
							 "X" => 0);
	my %starboards = reverse %ports;
	my $return = $ports{$val} + $amt;
	if ($return < 0) { $return = 0; }
	if ($return > 5) { $return = 5; }
	return $starboards{$return};
}
# alter other values
sub adj_other
{
	my $val = shift;
	my $amt = shift;
	my $return;

	# do the sums, send the result...
	if ($val =~ /[A-L]/) { $return = &convert($val) + $amt; }
	elsif ($val =~ /[0-9]/) { $return = $val + $amt; }
	else { $return = $val; }
	if ($return < 0) { $return = 0; }
	if ($return > 9) { $return = &convert($return); }
	return $return;
}
# convert numbers &c 
sub convert
{
	my $val = shift;
	my %nums = ("A" => 10,
							"B" => 11,
							"C" => 12,
							"D" => 13,
							"E" => 14,
							"F" => 15,
						  "G" => 16,
						  "H" => 17,
						  "J" => 18,
						  "K" => 19,
						  "L" => 20,
						  "M" => 21,
						  "N" => 22,
						  "P" => 23,
						  "Q" => 24,
						  "R" => 25,
						  "S" => 26);
	my %letters = reverse %nums;
	
	if ($val =~ /[A-S]/) { return $nums{$val}; }
	elsif ($val > 9) { return $letters{$val}; }
	else { return $val; } 
}
# check that atmosphere and tech are 
# in agreement
sub techcheck
{
	my $tl = shift;
	my $atmos = shift;
	my %mintl = (0 => 7,
							 1 => 7,
							 2 => 5,
							 3 => 5,
							 4 => 3,
							 7 => 3,
							 9 => 3,
							 'A' => 7,
							 'B' => 8,
							 'C' => 8);
	if ($tl =~ /[A-H]/)  {return 0; }
	elsif ($tl >= $mintl{$atmos}) {return 0; }
	else { return $mintl{$atmos}; }
}
