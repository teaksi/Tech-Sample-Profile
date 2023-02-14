#!/usr/bin/perl
# 2.9 		  2022-07-05	  Chirag	   Task#8938:->	We recently modified SE024 to support creating customer invoices salestax data while creating invoices as per Task#8908. 
														#We need to implement the same function while creating PIA invoices as well where productinvoice.source = T and productinvoice.type = 'D' and it will also be implemented subject to locationsystem SLSTX = S.						
# 2.8 		  2020-12-17	  Chirag	   Task#8908:->Please modify SE024 to support Sales Tax System. Let's implement only when locationsystem SLSTX = 'S'.Spec below for the reference:
#														https://teakwce.com/spec/Applications/application_concepts/sales_tax_system.htm

# 2.7 		  2020-12-01	  Chirag	   Task#8910:->While testing the fixes to switch Roltek service charges from SF to LI, we realized that SE024 process only one LI service charge and does not create multiple transactivitysc and related prodcutinvoice S records.

													   #Please fix it so that it process all service charges linked to location and create proper transactivitysc and productinvoice type "S" records for each service charge.
# 2.6 		  2020-11-25	  Chirag	   Task#8904:->Modify SE024 to support negative amount in customer percentage service charge (Type PC) if location system NEGSC = Y. 
														#At present when location has customer percentage service charge (Type PC) then SE024 creates transactivitysc records if invoice amount is positive, service doesn't create any trasctivitysc if invoice amount it negative. 
														#Modify service to create negative amount transactivitysc if invoice amount is negative and location system NEGSE = Y.
														#If location system NEGSE = N or doesn't exist do currently what service is doing (Don't create any transactivitysc if invoice is negative)

# 2.5 		  2020-11-12	  Chirag	   Task#8896:->I notice that SE024 is not creating correct transactivitysc records for service change type PC (Customer Percentage) when there are multiple service change assign to a single location. I notice that service is calculating trasactivitysc amount based on first available record from table servicecharge.
# 2.4 		  2020-09-30	  Nimesh	   Task#8840:->We have recently seen instances when clients would not know whether billing process has been completed or not. So, in order to make sure clients know once billing process is done for the day, we would send a notification email to client contact.
													    #We will modify SE024 to test after it updates clientsystem SE024 to next Run Date, test if Productinvoice type = 'I' or 'D' and source = 'T' or 'S' record has been created where productinvoice.invdate = today's date for the related client location OR Productpayables type = 'I' and source = 'T' has been created where Productpayables.payabledate = today's date for the related client location
														#If yes, we will check if notify group "INV" exists related to client location and if yes, find all person linked to the notify group for the client location and send email like below:
														#From Email : noreply@teakwce.com
														#Email Subject : "Billing has been Processed for MM/DD/YY for XX-YY"
														#where XX-YY would be Company.Name-Location.Sdesc for the Client location.
														#Email Body : Customer invoices or paybales have been created with an invoice date XX/YY/ZZ. Please review customer invoices going to Data>>>Billing and Receiving and payables going to Data>>>Payables.
# 2.3 		  2020-09-16	  Chirag	   Task#8823:->This service is getting crashed when there are proper billing base date is not set on a customer location and this results into whole invoice getting stuck for all clients.
														#Please fix it so that when it come across a situation like this where SE024 can not find proper billing period end base date for a customer location, skip the customer location billing, instead of service getting crashed 
# 2.2 		  2020-07-28	  Chirag	   Task#8756:->Implement the processing of ServiceCharge.Type = "LI" service charges.  Its a fixed dollar amount invoice based on ServiceChargePricing.Amount but it will created by SE024 only when a related producinvoice source "T" record exists for the billing period for the customer location being processed. If "T" record is found, it will create a transactivtysc record and create a productinvoice "S" record.
# 2.1 		  2020-02-27	  Chirag	   Task#8532: As per Task#8460, We modified this service to set locationsystem AUBIL = 'strvar = "NOW() + Lag Time' to run automated processing of invoices, but we realized that we are giving option to client to process it now as well. So, when even SE024 updates locationsystem AUBIL = 'strvar = "NOW() + Lag Time', it should also update locationsystem 38AUB strvar = "NOW() + Lag Time' as well.
# 2.0 		  2019-12-30	  Chirag	   Task#8460: We need to modify SE024 to support triggering the automated processing of invoices, so we need to make change:
# 1.9		  2019-10-23	  SBZ			Task#8394: We need to modify this service to test if locationsystem SUMTA = Y and if yes, we need to create invoicetalink records, when we create ProductPayables and Delivery Fees as well similar to what we did when productinvoice type "I" record being created.
# 1.8		  2019-06-10	  Chirag	   Task#8163: When we implemented the changes in SE024 as per Task#8094, its not creating correct invoicetalink records in those cases when a client location has wholesaler invoices being created as well.
# 1.7		  2019-04-26	  Chirag	   Task#8094: Please modify this program to support populating records to invoicetalink table which will be a link between productinvoice type I records and transactivity records
#                                          Task#8060: SE024 was getting crashed since on one of the locations routelink.billingperiodbasedate was not set.
# 1.6		  2019-02-27	  Chirag	   Task#7306: We should check if routelink.billigperiodbase date is set, when we are processing daycode.type = 'X' and if it's not set create an error message.  just like 'B' , 'J','K' and 'L'.
# 1.5		  2018-05-21	  Chirag	   Task#7681: Please make two changes to PIA logic:
														#1: When we create Productinvoice I records for PIA Customers, we should test if Total SUM of I+P+C = 0 and if yes, we should update all productinvoice records for that customer/period end date to Paid Stage i.e. update productinvoice.billingflag = 'P'
														#2: We seems to be creating a type "D" productinvoice record each time with amount same as final invoice when ever we create a final invoice i.e. productinvoiuce type I record. This seems to be bug and should not happen.
# 1.4		  2017-08-08	  Shahbaz	   Task#7306: Please modify this service to create productinvoice or productpayables irrespective of Product.producttype
# 1.3		  2017-07-20	  Chirag	   Task#7256: Please modify this service to support processing billing for a client location prior to billing period
#										   Task#7185: Make modifications to support lagged returns.  If DayCode.Type = "T", "C", or "M", instead of including returns where DateX is in the current billing period, we will include returns that are in the prior billing period.
# 1.2		  2017-05-09	  Chirag	   Task#7083: Please modify the "Create Product Payables" function to support lagged processing of transactivity .
# 1.1		  2017-02-23	  Shahbaz	   Task#4385: Please implement the revised PIA.
# 1.0         2016-11-22      Bela         Task#6868: With respect to Source = "T" or "S", if the Invoice Method (RouteLink.InvoiceMethod) is "Don't Process Invoice" (RouteLink.InvoiceMethod = "N"), it should not create ProductInvoice "I" records.
# 0.0         2015-09-17      Admin           Service to Create ProductInvoice Records.
#====================================


#
#	SE024 - Service to Create ProductInvoice Records
#	------------------------------------------------
#
#	Author			:FSTPL
#	Created For		:Mr. Fergus O'Scannlain
#	Created On		:12/15/2003
#	Last Modified on:02/23/2009
#   (c) Copyright 2003-2009 Teak Systems Incorporated.
#	Desctiption		:
#

#------------------- Paths of Other required scripts -----------------------
use lib "./";
use lib "./cm";
use lib "./se";

#------------------ Module Used by SE024 ------------------
use strict;
use DBI;
use cvt_general;
use Time::Local;
use date;
use POSIX;
use archfunc;
use MIME::Parser; # To parse the EMail attachment

my $dbstr = "dbstr";
cvt_general::DatabaseString(\$dbstr);
my $dbh = DBI->connect(eval($dbstr)) or die "Error in opening Database $DBI::errstr\n";

my $logname = ">./logs/cm/se024.log";
my $debug = 1;
my $sql;
my $sth;

#-------------- Taking Delay time, Startflag from System table -----------------
$sql = "SELECT intvar FROM system WHERE recid = 'SE024'";
#print "$sql;\n" if ($debug);
$sth = $dbh->prepare($sql);
$sth->execute() || die "$sql\n";
my $se024 = ($sth->fetchrow_array)[0];
$sth->finish();

$sql = "SELECT charvar FROM system WHERE recid = 'SP024'";
#print "$sql;\n" if ($debug);
$sth = $dbh->prepare($sql);
$sth->execute() || die "$sql\n";
my $startflag = ($sth->fetchrow_array)[0];
$sth->finish();

if($startflag eq "Y"){
	$sql = "UPDATE system SET intvar = $$ WHERE recid = 'SP024'";
	#print "$sql;\n" if ($debug);
	$dbh->do($sql) or die "Error in Query $sql\n";
} else {
	$dbh->disconnect();
	exit 0;
}

my $runDate = new date(); #cvt_general::SysDate();
my $val_DTRAD = "";
my $val_INDEF = "";
my $val_MANAR = 0;
my $val_MANCR = 0;
my $val_MANRR = 0;
my $format = "%0.2f";
my $maxTaRecId = 0;
my $maxTaSCRecId = 0;
my $isAutomaticTrigger = 0;
my $invoicedPDEndDate = "";
my $archObj = new archfunc();

# Sales Tax Related Variables
my $val_SLSTX = "";

while ($startflag eq "Y") {

	my @MANAR;
	my @MANCR;
	my @MANRR;
	my %clientRunTime;

	$sql = "SELECT strvar FROM system WHERE recid = 'SE024'";
#	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $dateString = ($sth->fetchrow_array())[0];
	$sth->finish();

	my $val_SE024 = new date($dateString);

	$clientRunTime{"all"} = $dateString;

	$sql = "SELECT clientid, strvar FROM clientsystem WHERE recid = 'SE024' AND (endeffdt = '0000-00-00' OR endeffdt > NOW() OR endeffdt IS NULL)";
#	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $isClientRunTimeExists = $sth->rows();
	while (my @record = $sth->fetchrow_array()) {
		$clientRunTime{"$record[0]"} = $record[1];
	}
	$sth->finish();

	$val_MANAR = 0;
	$sql = "SELECT DISTINCT(locationid), datevar FROM locationsystem WHERE recid = 'MANAR' AND charvar = 'Y' AND strvar = 'YES'";
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	$val_MANAR = $sth->rows();
	while (my @temparr = $sth->fetchrow_array()) {
		push @MANAR, \@temparr;
	}
	$sth->finish();

	if ($val_MANAR == 0) {
		$val_MANCR = 0;
		$sql = "SELECT DISTINCT(locationid), datevar, intvar FROM locationsystem WHERE recid = 'MANCR' AND charvar = 'Y' AND strvar = 'YES'";
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		$val_MANCR = $sth->rows();
		while (my @temparr = $sth->fetchrow_array()) {
			push @MANCR, \@temparr;
		}
		$sth->finish();

		if ($val_MANCR == 0) {
			$val_MANRR = 0;
			$sql = "SELECT DISTINCT(locationid), datevar FROM locationsystem WHERE recid = 'MANRR' AND charvar = 'Y' AND strvar = 'YES'";
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			$val_MANRR = $sth->rows();
			while (my @temparr = $sth->fetchrow_array()) {
				push @MANRR, \@temparr;
			}
			$sth->finish();
		}
	}


	#YYYY-MM-DD-HH-MM-SS
#	$dateString = cvt_general::DateTimeToSec($dateString);

	my $sysTime = $val_SE024->systemDateTime();


	#Test if system time is higher then SE024 or it's a manual execution
	if($val_SE024->compareDateTime($sysTime) > 0 || $isClientRunTimeExists > 0 || $val_MANAR > 0 || $val_MANCR > 0  || $val_MANRR > 0) {

		open log_file,$logname;
		select log_file;

		if ($val_SE024->compareDateTime($sysTime) > 0 && $val_MANAR == 0 && $val_MANCR == 0 && $val_MANRR == 0) {

#			print "=========== Automatic Trigger ================\n" if ($debug);
			$isAutomaticTrigger = 1;

		} else {

			if ($val_MANAR > 0) {
				print "=========== MANAR - Manual Trigger ================\n" if ($debug);
			} elsif ($val_MANCR > 0) {
				print "=========== MANCR - Manual Trigger ================\n" if ($debug);
			} elsif ($val_MANRR > 0) {
				print "=========== MANRR - Manual Trigger ================\n" if ($debug);
			} elsif($isClientRunTimeExists > 0) {
				print "=========== Automatic Trigger ================\n" if ($debug);
			}

		}

		$sql = "SELECT intvar FROM system WHERE recid = 'DTRAD'";
#		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		$val_DTRAD = ($sth->fetchrow_array())[0];
		$sth->finish();

		$sql = "SELECT datevar FROM system WHERE recid = 'INDEF'";
#		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		$val_INDEF = ($sth->fetchrow_array())[0];
		$sth->finish();

		if (!(length($val_DTRAD) > 0 && $val_DTRAD > 0)) {
			$val_DTRAD = 0;
		}

		$format = "%0.".$val_DTRAD."f";

		$runDate->setDate($runDate->systemDate());


		my @clientLocations ;
		if ($val_MANAR == 0 && $val_MANCR == 0 && $val_MANRR == 0) {
			$sql = "SELECT DISTINCT(locationid) FROM locationsystem WHERE recid = 'SRVCE' AND strvar = 'DT' AND (endeffdt = '0000-00-00' OR endeffdt is null OR endeffdt > '". $runDate->getDate() ."')";
#			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my $refClientLocation = $sth->fetchall_arrayref();
			$sth->finish();

			@clientLocations = @$refClientLocation;
		} elsif ($val_MANAR > 0){
			@clientLocations = @MANAR;
		} elsif ($val_MANCR > 0){
			@clientLocations = @MANCR;
		} elsif ($val_MANRR > 0){
			@clientLocations = @MANRR;
		}

		foreach my $record (@clientLocations) {

			$invoicedPDEndDate = "";

			if (length($record->[0]) == 0 || (length($record->[0]) > 0 && $record->[0] == 0)) {
#				print "Moving to Next LocationID\n" if ($debug);
				next ;
			}

			$val_SLSTX = "N"; #Task#8908
			$sql = "SELECT charvar FROM locationsystem WHERE recid = 'SLSTX' AND locationid = '$record->[0]' AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > NOW())";
			#print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			($val_SLSTX) = $sth->fetchrow_array();
			$sth->finish();

			if (length($val_SLSTX) == 0) {
				$val_SLSTX = "N";#Task#8908
			}

			$sql = "SELECT companyid FROM locationlink WHERE locationid = '$record->[0]'";
			#print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my $clientId = ($sth->fetchrow_array())[0];
			$sth->finish();


			if ($val_MANAR == 0 && $val_MANCR == 0 && $val_MANRR == 0) {
				if (exists $clientRunTime{"$clientId"}) {
					#print "ClientRunTime:" . $clientRunTime{"$clientId"} . " - $sysTime\n" if ($debug);
					my $tempClientRunTime = new date($clientRunTime{"$clientId"});
					if ($tempClientRunTime->compareDateTime($sysTime) <= 0) {
						#print "ClientRunTime: Moving next\n" if ($debug);
						next;
					}
				} elsif($val_SE024->compareDateTime($sysTime) <= 0) {
					#print "SystemRunTime:" . $val_SE024->getDateTime(). " - $sysTime\n" if ($debug);
					next;
				} else {
					print "Running for $clientId - SystemRunTime:" . $val_SE024->getDateTime(). " - $sysTime\n" if ($debug);
				}
			}

			$archObj->setClient($dbh, "clientId", $clientId, "clientLocId", $record->[0]);

			if (length($archObj->getArchInfo("splitSuffix")) == 0) {
				print "No Archive Suffix found... moveing to next\n" if ($debug);
				next;
			}

			if ($val_MANAR > 0) {
				$runDate->setDate($record->[1]);
			}

			if ($val_MANRR > 0) {
				$runDate->setDate($record->[1]);
			}

			my $specificRouteId = 0;

			$sql = $archObj->processSQL("SELECT MAX(recid) FROM transactivity WHERE locationid = '$record->[0]'");
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			($maxTaRecId) = $sth->fetchrow_array();
			$sth->finish();

			if (length($maxTaRecId) == 0) {
				$maxTaRecId = 0;
			}

			$sql = $archObj->processSQL("SELECT MAX(recid) FROM transactivitysc WHERE locationid = '$record->[0]'");
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			($maxTaSCRecId) = $sth->fetchrow_array();
			$sth->finish();

			if (length($maxTaSCRecId) == 0) {
				$maxTaSCRecId = 0;
			}


			$sql = "UPDATE system SET strvar = NOW(), charvar = 'W', realvar = '$clientId' WHERE recid = 'ARCHW'";
			print "$sql\n" if ($debug);
			$dbh->do($sql) or die "$sql;\n";

			
			my $Email_Inv_Invoice = 0; #Task#8840
			my $Email_Inv_payable = 0; #Task#8840
			my $Email_Inv_scahrge = 0; #Task#8840
			if ($val_MANCR > 0) {
				$runDate->setDate($record->[1]);
				$specificRouteId = $record->[2];

				if (length($archObj->getArchInfo("splitSuffix")) > 0) {
					print "\n============== T - Invoice Manual ==========\n" if ($debug);
					processManInvoice($clientId, $record->[0], $specificRouteId);
					system("perl se/cm/tra50_archdata.pl $clientId FORCECOPY");
				}


				$sql = "UPDATE locationsystem SET strvar = 'NO', datevar = NULL, intvar = NULL WHERE recid = 'MANCR' AND locationid = '$record->[0]'";
				print "$sql\n" if ($debug);
				$dbh->do($sql) or die "$sql;\n";

			} else {
				if (length($archObj->getArchInfo("splitSuffix")) > 0) {

						
					#T - Publication Transaction - Invoice to Customer for Specific Publications based on copies delivered
					print "\n============== T - Invoice ==========\n" if ($debug);
					$Email_Inv_Invoice = processClient($clientId, $record->[0]); #Task#8840
					
					
					$sql = $archObj->processSQL("UPDATE transactivity SET archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE closeddatecust = '" . $runDate->getDate() . "' AND type IN ('DE', 'PU', 'AD') AND locationid = '". $record->[0] ."'");
					print "$sql\n" if ($debug);
					$dbh->do($sql) or die "$sql;\n";
					system("perl se/cm/tra50_archdata.pl $clientId FORCECOPY");
					
					

					#T - Publication Transaction - Payable to Vendor for Specific Publications based on copies delivered (net of returns):
					print "\n============== T - Payables ==========\n" if ($debug);
					$Email_Inv_payable = processVendors($clientId, $record->[0]); #Task#8840
					$sql = $archObj->processSQL("UPDATE transactivity SET archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE closeddatevend = '" . $runDate->getDate() . "' AND type IN ('DE', 'PU', 'AD') AND locationid = '". $record->[0] ."'");
					print "$sql\n" if ($debug);
					$dbh->do($sql) or die "$sql;\n";
					system("perl se/cm/tra50_archdata.pl $clientId FORCECOPY");
					
					

					#F - Delivery Fee - Fee that the Publisher pays to get the publication delivered based on copies delivered
					print "\n============== F - Delivery Fee ==========\n" if ($debug);
					processDeliveryFee($clientId, $record->[0]);
					$sql = $archObj->processSQL("UPDATE transactivity SET archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE closeddatevendinv = '" . $runDate->getDate() . "' AND type IN ('DE', 'PU', 'AD') AND locationid = '". $record->[0] ."'");
					print "$sql\n" if ($debug);
					$dbh->do($sql) or die "$sql;\n";
					system("perl se/cm/tra50_archdata.pl $clientId FORCECOPY");


					#S - Service Charge Pay/Bill to Customer
					print "\n============== S - Service Charge Invoice ==========\n" if ($debug);
					print "\n============= S - Service Charge Payables ==========\n" if ($debug);
					$Email_Inv_scahrge = processServiceChargeCust($clientId, $record->[0]); #Task#8840
					$sql = $archObj->processSQL("UPDATE /*SE024*/ transactivitysc SET archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE closeddatecust = '" . $runDate->getDate() . "' AND type IN ('BD', 'PF', 'DP', 'SF', 'VF', 'VR', 'VC', 'DF', 'DS', 'PS','PC','CD','IP','IQ','IT','IB','IC','IG','IM','IA','IX','IF','IL','ID','IS','IY','PU','ST','IE','LI') AND locationid = '". $record->[0] ."'");#Task#8756
					print "$sql\n" if ($debug);
					$dbh->do($sql) or die "$sql;\n";
					system("perl se/cm/tra50_archdata.pl $clientId FORCECOPY");


					#P - Service Charge - Bill to Publisher/Vendor
					print "\n============== P - Service Charge Invoice ==========\n" if ($debug);
					processServiceChargeVend($clientId, $record->[0]);
					$sql = $archObj->processSQL("UPDATE transactivitysc SET archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE closeddatevendinv = '" . $runDate->getDate() . "' AND type IN ('BD', 'PF', 'DP', 'DF', 'SF', 'VF', 'VR', 'VC', 'DS', 'DP','CD','IP','IQ','IT','IB','IC','IG','IM','IA','IX','IF','IL','ID','IS','IY','PU','ST','IE') AND locationid = '". $record->[0] ."'");
					print "$sql\n" if ($debug);
					$dbh->do($sql) or die "$sql;\n";
					system("perl se/cm/tra50_archdata.pl $clientId FORCECOPY");


					#S - Service Charge Pay to Publisher/Vendor
					print "\n============== P - Service Charge Payables ==========\n" if ($debug);
					processSCVendPay($clientId, $record->[0]);
					$sql = $archObj->processSQL("UPDATE transactivitysc SET archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE closeddatevend = '" . $runDate->getDate() . "' AND type IN ('BD', 'PF', 'DP', 'DF', 'SF', 'VF', 'VR', 'VC', 'DS', 'DP','CD','IP','IQ','IT','IB','IC','IG','IM','IA','IX','IF','IL','ID','IS','IY','PU','ST','IE') AND locationid = '". $record->[0] ."'");
					print "$sql\n" if ($debug);
					$dbh->do($sql) or die "$sql;\n";
					system("perl se/cm/tra50_archdata.pl $clientId FORCECOPY");


					#V - Vending Machine Event
					print "\n============== V - Vending Machine Event Invoice ==========\n" if ($debug);
					print "\n============== V - Vending Machine Event Payables ==========\n" if ($debug);
					processVendingMCEvent($clientId,$record->[0]);
					$dbh->do($sql) or die "$sql;\n";
					system("perl se/cm/tra50_archdata.pl $clientId FORCECOPY");

					#D - Advance Invoice for Customers
					print "\n============== D - PIA Customer Records ==========\n" if ($debug);
					processPIACustomer($clientId,$record->[0]);
					system("perl se/cm/tra50_archdata.pl $clientId FORCECOPY");

				}

				if ($val_MANAR > 0) {
					$sql = "UPDATE locationsystem SET strvar = 'NO', datevar = NULL WHERE recid = 'MANAR' AND locationid = '$record->[0]'";
					print "$sql\n" if ($debug);
					$dbh->do($sql) or die "$sql;\n";
				} elsif ($val_MANRR > 0) {
					$sql = "UPDATE locationsystem SET strvar = 'NO', datevar = NULL WHERE recid = 'MANRR' AND locationid = '$record->[0]'";
					print "$sql\n" if ($debug);
					$dbh->do($sql) or die "$sql;\n";
				}

				if (length($archObj->getArchInfo("splitSuffix")) > 0) {
					print "\n========== Setting INDEF to Old UnInvoiced records ==============\n" if($debug);
					setINDEF($clientId, $record->[0]);
					system("perl se/cm/tra50_archdata.pl $clientId FORCECOPY");
				}

			}

			#if ($val_MANAR == 0 && $val_MANCR == 0 && $val_MANRR == 0) { #Commented#8840
			    print "Email_Inv_Invoice: $Email_Inv_Invoice Email_Inv_payable: $Email_Inv_payable Email_Inv_scahrge: $Email_Inv_scahrge \n" if ($debug); #Task#8840
			    if (exists $clientRunTime{"$clientId"}) {
					my $tempClientRunDate = new date($clientRunTime{"$clientId"});
					$sql = "UPDATE clientsystem SET strvar = '". $tempClientRunDate->addDaysToDateTime(1) ."' , datevar = now() WHERE recid = 'SE024' AND clientid = '$clientId'";
					print "$sql\n" if ($debug);
					$dbh->do($sql) or die "$sql;\n";

					# ClientSystem = SE024 cases, when the processing is complete for a client,
					# send an email to those listed in NotifyGroup "INV".
					# (Persons related by NotifyPerson.PersonLinkId where GroupCode = "INV")
					if ($Email_Inv_Invoice == 1 || $Email_Inv_payable == 1 || $Email_Inv_scahrge == 1) { #Task#8840
			        my @emailList;
					$sql = "SELECT p.email FROM personlink pl, person p, notifyperson np, notifygrouplink ngl WHERE ngl.groupcode = 'INV' AND ngl.locationid = '$record->[0]' AND ngl.groupcode = np.groupcode AND np.personlinkid = pl.recid AND pl.locationid = ngl.locationid AND pl.personid = p.recid";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					while (my ($emailId) = $sth->fetchrow_array()) {
						push @emailList, $emailId;
					}
					$sth->finish();
                    #Commented#8840 Stars
					# Actually sending emails for notification.

					# my %tempHash;
				    # my @pdEndDates = grep(!$tempHash{$_}++, split(/,/, $invoicedPDEndDate));
					# @pdEndDates = sort @pdEndDates;
					# my $datesCount = @pdEndDates;
					# foreach my $tempDt (@pdEndDates) {
						# $tempDt = substr($tempDt, 5, 2) ."/". substr($tempDt, 9, 2) ."/". substr($tempDt, 2, 2);
					# }
					# $sql = "SELECT DATE_FORMAT(DATE_ADD(NOW(), INTERVAL intvar HOUR), '%H:%i') FROM locationsystem WHERE recid = 'TIMEO' AND locationid =  '$record->[0]'";
					# print "$sql\n" if ($debug);
					# $sth = $dbh->prepare($sql);
					# $sth->execute() or die "$sql;\n";
					# my ($formatedTime) = $sth->fetchrow_array();
					# $sth->finish();

					# if ($datesCount == 1) {
						# $message = "Processing for the period ending $pdEndDates[0] is completed at $formatedTime";
					# } else {
						# $message = "Processing for following period ending are completed at $formatedTime\n";
						# foreach  (@pdEndDates) {
							# $message .= "$_\n";
						# }
					# }
				    #Commented#8840 Ends
					#Task#8840 	Starts
					my $message = "";
					
					my $mm = substr($tempClientRunDate->getDate(),5,2);
					my $dd = substr($tempClientRunDate->getDate(), 8,2);
		            my $yy = substr($tempClientRunDate->getDate(), 2,2);
					$message = "Customer invoices or paybales have been created with an invoice date $mm/$dd/$yy. Please review customer invoices going to Data>>>Billing and Receiving and payables going to Data>>>Payables.\n";
					
					$sql = "SELECT /*se024*/ c.name FROM company c WHERE c.recid = '$clientId'";
					# print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my ($compName) = ($sth->fetchrow_array())[0];
					$sth->finish();
					
					$sql = "SELECT /*se024*/ l.sdesc locDesc FROM location l WHERE l.recid = '$record->[0]'";
					# print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my ($locName) = ($sth->fetchrow_array())[0];
					$sth->finish();
					
					my $subject = "Billing has been Processed for $mm/$dd/$yy for $compName-$locName";
					my $from = 'noreply@teakwce.com';
					#Task#8840 	Ends
					foreach my $emailTo (@emailList) {
						my $email = MIME::Entity->build(From => "$from",
														  To       => "$emailTo",
														  Subject  => "$subject",
														  Data	   => "$message");
						eval{
							$email->smtpsend;
							print "Mail sent to $emailTo From $from\n";
						};
						if($@){
							print "Could Not Able to send email to $emailTo\n" if ($debug);
			 			}
					}
				}
			}

			$sql = "UPDATE system SET strvar = NULL, charvar = 'Y', realvar = NULL WHERE recid = 'ARCHW'";
			print "$sql\n" if ($debug);
			$dbh->do($sql) or die "$sql;\n";

		}

		if ($isAutomaticTrigger) {
			$sql = "UPDATE system SET strvar = '". $val_SE024->addDaysToDateTime(1) ."' , datevar = now() WHERE recid = 'SE024'";
			print "$sql\n" if ($debug);
			$dbh->do($sql) or die "$sql;\n";
			$isAutomaticTrigger = 0;
		}

		close log_file;
	}

	sleep $se024;
	$sql = "SELECT charvar FROM system WHERE recid = 'SP024'";
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "Error in Query $DBI::errstr\n";
	$startflag = uc(($sth->fetchrow_array)[0]);
	$sth->finish();

}

exit 0;

#========================== ====================================

sub processVendingMCEvent {
	my ($clientId, $clientLocId) = @_;

	$sql = "SELECT recid, intvar, datevar FROM locationsystem WHERE locationid = '$clientLocId' AND recid IN ('VMPDB', 'VBPDB', 'VMSCB', 'VBSCB', 'VMPDP', 'VBPDP', 'VMSCP', 'VBSCP')";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my %daycodeHash;
	while (my @arr = $sth->fetchrow_array()) {
		if ($arr[0] eq "VMPDB" || $arr[0] eq "VMSCB" || $arr[0] eq "VMPDP" || $arr[0] eq "VMSCP") {
			$daycodeHash{"$arr[0]"} = $arr[1];
		} elsif ($arr[0] eq "VBPDB" || $arr[0] eq "VBSCB" || $arr[0] eq "VBPDP" || $arr[0] eq "VBSCP") {
			$daycodeHash{"$arr[0]"} = $arr[2];
		}
	}
	$sth->finish();

	if (!(length($daycodeHash{"VMSCB"}) > 0 && $daycodeHash{"VMSCB"} > 0)) {
		return;
	}
	if (!(length($daycodeHash{"VMPDB"}) > 0 && $daycodeHash{"VMPDB"} > 0)) {
		return;
	}

	my $isLocationOpen = isLocationOpen($runDate->getDate(), $daycodeHash{"VMSCB"}, $daycodeHash{"VBSCB"}, $daycodeHash{"VMPDB"}, $daycodeHash{"VBPDB"});
	if ($isLocationOpen == 0) {
		return ;
	}

	$sql = "SELECT type, period, sequence FROM daycode WHERE recid = '$daycodeHash{\"VMSCB\"}'";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my ($type, $period, $sequence) = $sth->fetchrow_array();
	$sth->finish();

	# WHEN TYPE IS "L" THEN CHANGE THE RUNDATE BACK TO THE RELATIVE DAYS FOR THE BILLINGDAYCODEID
	my $tempRunDate = '';
	my $TmpendingDate =  '';
	if($type eq "L"){
		$tempRunDate = $runDate->getDate();
		# Finding the lagging period
		my $lag = $sequence * 7;
		$runDate->setDate($runDate->addDaysToDate($lag * -1));
	}
	my $endingDate = getEndingDate($period, $runDate->getDate(), $daycodeHash{"VMPDB"}, $daycodeHash{"VBPDB"});
	print "ending_date:$endingDate\n" if ($debug);

	if (length($tempRunDate) > 0) {
		$runDate->setDate($tempRunDate);
		$tempRunDate = '';
	}


	my @vendingEventIds;
	my $vendingEventIds = "0";
	$sql = "SELECT recid FROM vendingevent WHERE type = 'S'";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	while (my @temp = $sth->fetchrow_array()) {
		if (length($temp[0]) > 0 && $temp[0] > 0) {
			push @vendingEventIds, $temp[0];
			$vendingEventIds .= "," . $temp[0];
		}
	}
	$sth->finish();

	# selecting distinct owners of the vending machine
	$sql = "SELECT DISTINCT(ownerlocid) FROM vendingproblem WHERE clientlocid = '$clientLocId' AND (closeddateowner IS NULL OR closeddateowner = '0000-00-00')";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $refOwnerLocs = $sth->fetchall_arrayref();
	$sth->finish();

	my @ownerlocs = @$refOwnerLocs;

	foreach my $record (@ownerlocs) {
		my ($vendorLocId) = @{$record};

		if (length($vendorLocId) == 0 || $vendorLocId == 0) {
			next;
		}

		if (length($endingDate) > 0) {

			$sql = "SELECT recid, billingflag FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$vendorLocId' AND periodenddate = '$endingDate' AND type = 'I' AND source = 'V'";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my ($piRecId, $piBillingFlag) = $sth->fetchrow_array();
			$sth->finish();

			if (($piBillingFlag eq "Y" || $piBillingFlag eq "P") && length($piRecId) > 0 && $piRecId > 0) {
				next;
			}

			# checking wheter there is any records to bill the owner of the vending machine
			$sql = "SELECT recid, vendingeventid, fromdate, unitsales FROM vendingproblem WHERE todate != '0000-00-00' AND todate IS NOT NULL AND todate <= '$endingDate' AND clientlocid = '$clientLocId' AND ownerlocid = '$vendorLocId' AND (closeddateowner IS NULL OR closeddateowner = '0000-00-00') AND vendingeventid IN ($vendingEventIds)";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my ($isBillable) = $sth->rows();
			my ($refVendingProb) = $sth->fetchall_arrayref();
			$sth->finish();

			if ($isBillable == 0) {
				next;
			}

			my $records = 0;
			foreach my $rec (@{$refVendingProb}) {
				my ($vRecId, $vEventId, $fromDate, $amount) = @{$rec};

				$sql = "SELECT COUNT(*) FROM vendingprice WHERE effdt <= '$fromDate' AND vendingeventid = '$vEventId' AND salecost = 'S'  AND vendorlocid = '$vendorLocId' ORDER BY effdt DESC LIMIT 1";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my ($vpAmount) = $sth->fetchrow_array();
				$sth->finish();

				if ($amount == 0) {
					if ($vpAmount > 0) {
						# bill the record
						$sql = "UPDATE vendingproblem SET closeddateowner = '". $runDate->getDate() ."', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid = '$vRecId'";
						print "$sql\n" if ($debug);
						$dbh->do($sql) or die "$sql;\n";
						$records++;
					} else {
						# do not bill the record
						$sql = "UPDATE vendingproblem SET closeddateowner = '$val_INDEF', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid = '$vRecId'";
						print "$sql\n" if ($debug);
						$dbh->do($sql) or die "$sql;\n";
					}
				} else {
					$sql = "UPDATE vendingproblem SET closeddateowner = '". $runDate->getDate() ."', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid = '$vRecId'";
					print "$sql\n" if ($debug);
					$dbh->do($sql) or die "$sql;\n";
					$records++;
				}
			}

			if ($records > 0) {
				$sql = "SELECT SUM(actquantity * unitsales) FROM vendingproblem WHERE closeddateowner = '". $runDate->getDate() ."' AND todate <= '$endingDate' AND clientlocid = '$clientLocId' AND ownerlocid = '$vendorLocId'";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my $vendorAmount = ($sth->fetchrow_array())[0];
				$sth->finish();

				if (length($vendorAmount) > 0 && $vendorAmount > 0) {
					$vendorAmount = sprintf("$format",$vendorAmount);
				} else {
					$vendorAmount = 0;
				}

				if (length($piRecId) > 0 && $piRecId > 0) {
					$sql = "UPDATE productinvoice SET totalamount = '$vendorAmount', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid = '$piRecId'";
					print "$sql\n" if ($debug);
					$dbh->do($sql) or die "$sql;\n";
				} else {
					if ($vendorAmount > 0) {
						$sql = "INSERT INTO productinvoice(clientlocid, customerlocid, type, invdate, periodenddate, totalamount, billingflag, source) values('$clientLocId', '$vendorLocId', 'I', '". $runDate->getDate() ."', '$endingDate', '$vendorAmount', 'N', 'V')";
						print "$sql\n" if ($debug);
						$dbh->do($sql) or die "$sql;\n";
						my $productInvoiceId = $dbh->{'mysql_insertid'};
					}
				}
			}
		}
	}
# =============== Payables  ============================
# ======================================================
	if (!(length($daycodeHash{"VMSCP"}) > 0 && $daycodeHash{"VMSCP"} > 0)) {
		return;
	}
	if (!(length($daycodeHash{"VMPDP"}) > 0 && $daycodeHash{"VMPDP"} > 0)) {
		return;
	}

	my $ispaylocopen = isLocationOpen($runDate->getDate(), $daycodeHash{"VMSCP"}, $daycodeHash{"VBSCP"}, $daycodeHash{"VMPDP"}, $daycodeHash{"VBPDP"});
	if ($ispaylocopen == 0) {
		return ;
	}

	$sql = "SELECT type, period, sequence FROM daycode WHERE recid = '$daycodeHash{\"VMSCP\"}'";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	($type, $period, $sequence) = $sth->fetchrow_array();
	$sth->finish();

	# WHEN TYPE IS "L" THEN CHANGE THE RUNDATE BACK TO THE RELATIVE DAYS FOR THE BILLINGDAYCODEID
	$tempRunDate = '';
	if($type eq "L"){
		$tempRunDate = $runDate->getDate();
		# Finding the lagging period
		my $lag = $sequence * 7;
		$runDate->setDate($runDate->addDaysToDate($lag * -1));
	} # end of lagging period condition.

	$endingDate = '';
	$endingDate = getEndingDate($period, $runDate->getDate(), $daycodeHash{"VMPDP"}, $daycodeHash{"VBPDP"});
	print "ending_date:$endingDate\n" if ($debug);

	if (length($tempRunDate) > 0) {
		$runDate->setDate($tempRunDate);
		$tempRunDate = '';
	}

	# finding vendors records from vendingproblem
	$sql = "SELECT DISTINCT(vendorlocid) FROM vendingproblem WHERE clientlocid = '$clientLocId' AND (closeddatevend IS NULL OR closeddatevend = '0000-00-00') AND vendorlocid != 0";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $refVendorLocs = $sth->fetchall_arrayref();
	$sth->finish();

	my @vendorLocs = @$refVendorLocs;

	foreach my $record (@vendorLocs) {
		my $vendorLocId = $record->[0];

		# finding the publications delivered from that vendor
		$sql = "SELECT DISTINCT(vll.publicationid) FROM vendinglocationlink vll, vendingproblem vp WHERE vp.vendorlocid = '$vendorLocId' AND vp.vendinglocid = vll.locationid AND vll.publicationid != 0";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my $refProducts = $sth->fetchall_arrayref();
		$sth->finish();

		my @products = @{$refProducts};
		foreach my $record1 (@products) {
			my ($productId) = @$record1;

			$sql = "SELECT COUNT(*) FROM vendingproblem WHERE vendorlocid = '$vendorLocId' AND (closeddatevend IS NULL OR closeddatevend = '0000-00-00') AND todate <= '$endingDate' AND vendingeventid IN ($vendingEventIds)";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my $isExists = ($sth->fetchrow_array())[0];
			$sth->finish();
			if($isExists) {

				$sql = "SELECT recid, billingflag FROM productpayables WHERE clientlocid = '$clientLocId' AND vendorlocid = '$vendorLocId' AND periodenddate = '$endingDate' AND type = 'I' AND source = 'V' AND publicationid = '$productId'";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my ($productPayRecId, $productPayableBillingFlag) = $sth->fetchrow_array();
				$sth->finish();

				if (($productPayableBillingFlag eq "Y" || $productPayableBillingFlag eq "P") && length($productPayRecId) > 0 && $productPayRecId > 0) {
					next;
				}

				my $validIds = "";
				foreach  (@vendingEventIds) {
					$sql = "SELECT amount FROM vendingprice WHERE vendorlocid = '$vendorLocId' AND vendingeventid = '$_' AND salecost = 'C' AND effdt <= NOW() ORDER BY effdt DESC LIMIT 1";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my ($tempAmount) = $sth->fetchrow_array();
					if (length($tempAmount) > 0 && $tempAmount == 0) {
						$validIds .= "$_" . ",";
					}
					$sth->finish();
				}

				$validIds =~ s/,$//;

				if (length($validIds) > 0) {
					$sql = "UPDATE vendingproblem SET closeddatevend = '$val_INDEF', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE todate != '0000-00-00' AND todate IS NOT NULL AND todate <= '$endingDate' AND clientlocid = '$clientLocId' AND ownerlocid = '$vendorLocId' AND (closeddatevend IS NULL OR closeddatevend = '0000-00-00') AND (unitcost IS NULL OR unitcost = 0 OR unitcost = '') AND vendingeventid NOT IN ($validIds)";
					print "$sql\n" if ($debug);
					$dbh->do($sql) or die "$sql;\n";
				} else {
					$sql = "UPDATE vendingproblem SET closeddatevend = '$val_INDEF', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE vendinglocid = '$vendorLocId' AND (closeddatevend IS NULL OR closeddatevend = '0000-00-00') AND todate != '0000-00-00' AND todate IS NOT NULL AND todate <= '$endingDate' AND (unitcost IS NULL OR unitcost = 0 OR unitcost = '') AND vendingeventid IN ($vendingEventIds)";
					print "$sql\n" if ($debug);
					$dbh->do($sql) or die "$sql;\n";
				}

				$sql = "UPDATE vendingproblem SET closeddatevend = '". $runDate->getDate() ."', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE vendinglocid = '$vendorLocId' AND (closeddatevend IS NULL OR closeddatevend = '0000-00-00') AND todate <= '$endingDate' AND vendingeventid IN ($vendingEventIds)";
				print "$sql\n" if ($debug);
				my $rows = $dbh->do($sql) or die "$sql;\n";
				if ($rows > 0) {

					$sql = "SELECT ROUND(SUM(unitcost * actquantity), $val_DTRAD) FROM vendingproblem WHERE vendinglocid = '$vendorLocId' AND closeddatevend = '". $runDate->getDate() ."'";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my $amount = ($sth->fetchrow_array())[0];
					$sth->finish();

					if (length($amount) > 0 && $amount > 0) {
						$amount = sprintf("$format",$amount);
						$amount = $amount * -1;
					} else {
						$amount = 0;
					}

					if (length($productPayRecId) > 0 &&  $productPayRecId > 0) {
						$sql = "UPDATE productpayables SET totalamount = '$amount', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid = '$productPayRecId'";
						print "$sql\n" if ($debug);
						$dbh->do($sql) or die "$sql;\n";
					} else {
						if ($amount > 0) {
							$sql = "INSERT INTO productpayables(clientlocid, vendorlocid, publicationid, type, payabledate, periodenddate, totalamount, billingflag, source) values('$clientLocId', '$vendorLocId', '$productId', 'I', '". $runDate->getDate() ."', '$endingDate', $amount, 'N', 'V')";
							print "$sql\n" if ($debug);
							$dbh->do($sql) or die "$sql;\n";
						}
					}
				}
			}
		}
	}
}
sub processClientLagReturn{
	
			print "\n\n------------------------------ProcessClientLagReturn Call---------------------------\n\n";
	my ($clientId, $clientLocId,$customerLocId, $customerEffDt, $customerEndeffdt) = @_;

		my $Chk_AUBIL = 0; #Task#8460
		print "\n \n $clientId, $clientLocId,$customerLocId, $customerEffDt, $customerEndeffdt \n \n ";
		#my $customerLocId = $record->[0];
		if (length (cvt_general::trim($customerEndeffdt)) == 0) {
			$customerEndeffdt = '0000-00-00';
		}
		
		if (length (cvt_general::trim($customerLocId)) == 0) {
			$customerLocId = 0;
		}
		$sql = "SELECT intvar FROM locationsystem WHERE locationid = '$clientLocId' AND recid = 'PSTPR' AND (endeffdt = '0000-00-00' OR endeffdt IS NULL OR endeffdt > now())";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $personid_PSTPR = ($sth->fetchrow_array())[0];
	$sth->finish();
	if($personid_PSTPR eq '' || length($personid_PSTPR) == 0)
	{
		$personid_PSTPR = 0;
	}	
		my $NNBAT_Flag = 0;
		my $intvar_NNBAT = 0;
		my $charvar_NNBAT = 'N';
		my $full_Path = "/usr/local/apache/htdocs/twce/cm/";
		my $scriptName = "piafunc.php";
		my $called_from = "SE024";
		my $_cutOffDate = "0000-00-00";
		my $_RunDate = $runDate->getDate();
		# CHECKING OF BILLINGDAYCODEID AND BILLINGPERIODDAYCODEID IN ROUTELINK
		# AND ALSO CHECK THAT TODAY IS BILLINGDAY OR NOT.
		# AND ALSO CALCULATE THE ENDINGDATE.

		$sql = "SELECT billingdaycodeid, billingperioddaycodeid, billingbasedate, billingperiodbasedate, piaflag, period ,invoicemethod  FROM routelink LEFT JOIN daycode dc on billingperioddaycodeid = dc.recid  WHERE clientid = '$clientId' and locationid = '$customerLocId' AND (billingdaycodeid IS NOT NULL AND billingdaycodeid > 0) AND (billingperioddaycodeid IS NOT NULL AND billingperioddaycodeid > 0) ";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my ($billDaycodeId, $billPeriodDaycodeId, $billBaseDate, $billPeriodBaseDate, $piaFlag, $billPeriodDaycodePeriod,$InvoiceMethod) = $sth->fetchrow_array();
		$sth->finish();
		
		my $OrgbillPeriodDaycodePeriod = $billPeriodDaycodePeriod;
	
		print "$billDaycodeId, $billPeriodDaycodeId, $billBaseDate, $billPeriodBaseDate, $piaFlag, $billPeriodDaycodePeriod, $InvoiceMethod , Org:$OrgbillPeriodDaycodePeriod";
		
		if ($piaFlag eq "N") {
			print "PIA-FLG is N so Skipp\n";
			next ;
		}
		
		if($InvoiceMethod eq 'N')
		{
		  print " \n Don't process invoice \n";
		  next;
		}
		
		if (($billPeriodDaycodePeriod eq "B" || $billPeriodDaycodePeriod eq "J" || $billPeriodDaycodePeriod eq "K" || $billPeriodDaycodePeriod eq "L" || $billPeriodDaycodePeriod eq "X") && ($billPeriodBaseDate eq '0000-00-00' || $billPeriodBaseDate eq '') ) {
			print "When BillingPeriod = 'B' OR 'J' BillingPeriodBaseDate must be set \n";
			
			cvt_general::error_log01("SE024","","","D059","2","0","$clientId","0","0","billingperiodbasedate Not Set for CustomerLocId:$customerLocId for billingperioddaycodeid = $billPeriodDaycodeId");
			next;			
		}
		
		my $isBillingDay = isLocationOpen($runDate->getDate(), $billDaycodeId, $billBaseDate, $billPeriodDaycodeId, $billPeriodBaseDate);
		
		print "\n\n isBillingDay:$isBillingDay \n\n";
		if ($isBillingDay == 0) {
			next ;
		}
		
		my $billingFlag = "N";
		if ($piaFlag eq "Y") {
			$billingFlag = "Y";
		}

		$sql = "SELECT type, period, sequence FROM daycode WHERE recid = '$billDaycodeId'";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my ($type, $period, $sequence) = $sth->fetchrow_array();
		$sth->finish();
		
		
		
		
		# WHEN TYPE IS "L" THEN CHANGE THE RUNDATE BACK TO THE RELATIVE DAYS FOR THE BILLINGDAYCODEID
		my $tempRunDate = '';
		
		if($type eq "L"){
			$tempRunDate = $runDate->getDate;
			# Finding the lagging period
			my $lag = $sequence * 7;
			$runDate->setDate($runDate->addDaysToDate($lag * -1));

		}
	
	
	

		my $endingDate;
		my $prvEndingDate;
		
			print "isBillingDay9:$isBillingDay\nendingDate9:$endingDate\n" if($debug);
			
			$endingDate = getEndingDate($period, $runDate->getDate(), $billPeriodDaycodeId, $billPeriodBaseDate);
			 if ($isBillingDay =~ /-/) {
				$endingDate = $isBillingDay;
			}
			
			my $startDate = getStartingDate($period, $endingDate, $billPeriodDaycodeId, $billPeriodBaseDate);
			$prvEndingDate = getEndingDate($period, $startDate, $billPeriodDaycodeId, $billPeriodBaseDate);
			my $TmpStartDate = getStartingDate($period, $prvEndingDate, $billPeriodDaycodeId, $billPeriodBaseDate);
			
			print "isBillingDay:$isBillingDay\nendingDate:$endingDate\n" if($debug);
			print "\n\nprvEndingDate:$prvEndingDate\n TmpStartDate:$TmpStartDate\n\n" if($debug);
			if ($isBillingDay =~ /-/) {
				$endingDate = $isBillingDay;
			}
		

		print "endingDate = $endingDate\n" if($debug);
		
		if (length($endingDate) == 0) {
			#Billing date not found move to next product
			next ;
		}

		if (length($tempRunDate) > 0) {
			$runDate->setDate($tempRunDate);
			$tempRunDate = '';
		}

		# PROCESS OF THE TRANSACTION RECORDS FOR WHICH
		# CLOSEDCUSTDATE IS NULL OR ZERO.
		my $deAmount = 0;
		my $puAmount = 0;
		my $adAmount = 0;
		my $totalAmount = 0;
        my $ProdInvRecId = 0;
		$sql = "SELECT DISTINCT(productid) FROM standarddraw WHERE customerlocid = '$customerLocId' AND clientlocid = '$clientLocId' AND effdt <= '$endingDate' ORDER BY effdt DESC";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my $refTempProductList = $sth->fetchall_arrayref();
		my @tempProductList = @{$refTempProductList};
		$sth->finish();
		

		my $prodList = "";
		my $dProdList = "";
		my $wProdList = "";
		my %publisherList;
		foreach my $record (@tempProductList) {
			$sql = "SELECT COUNT(*) FROM product WHERE recid = '$record->[0]' /*AND producttype = 'PU' AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > '$endingDate')*/";
			$sth = $dbh->prepare($sql);
			$sth->execute() || die "$sql;\n";
			my $isValidProduct = ($sth->fetchrow_array())[0];
			$sth->finish();

			if($isValidProduct == 0) {
				next;
			}
			
			#my $startDate = getStartingDate($period, $endingDate, $billPeriodDaycodeId, $billPeriodBaseDate);
			
			$sql = "SELECT pricecodeid, invoicingent, invoicingentlocid  FROM standarddraw WHERE productid = '$record->[0]' AND customerlocid = '$customerLocId' AND clientlocid = '$clientLocId' AND effdt <= '$endingDate' /*AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > '$endingDate')*/ ORDER BY effdt DESC LIMIT 1";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my $isSDDrawExists = $sth->rows();
			my ($priceCodeId , $invEntity, $invEntLocId) = $sth->fetchrow_array();
			$sth->finish();

			# If no Effective StandardDraw exists then use the last deleted record based on PeriodEndDate
			if (!$isSDDrawExists) {
				$sql = "SELECT pricecodeid, invoicingent, invoicingentlocid  FROM standarddraw WHERE productid = '$record->[0]' AND customerlocid = '$customerLocId' AND clientlocid = '$clientLocId' AND effdt <= '$endingDate' ORDER BY effdt DESC LIMIT 1";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				($priceCodeId , $invEntity, $invEntLocId) = $sth->fetchrow_array();
				$sth->finish();
			}

			if (length($priceCodeId) == 0 || $priceCodeId == 0) {
				$prodList .= $record->[0] . ",";
			} else {
				if (length($invEntity) > 0 && $invEntity eq "W") {
					$wProdList .= "$record->[0]" . ",";
					if (length($invEntLocId) > 0 && $invEntLocId > 0) {
						if (not exists $publisherList{$invEntLocId}) {
							$publisherList{$invEntLocId} = "$record->[0]";
						} else {
							$publisherList{$invEntLocId} .= "," . "$record->[0]";
						}
					}
				} else {
					$dProdList .= "$record->[0]" . ",";
				}
			}
		}

		$dProdList =~ s/,$|^,//g;
		$dProdList =~ s/,,/,/g;
		$wProdList =~ s/,$|^,//g;
		$wProdList =~ s/,,/,/g;
		$prodList =~ s/,$|^,//g;
		$prodList =~ s/,,/,/g;

		print "dProdList:$dProdList\n" if($debug);
		print "wProdList:$wProdList\n" if($debug);
		print "prodList:$prodList\n" if($debug);

		

		if (length($prodList) > 0) {
			$sql = $archObj->processSQL("UPDATE transactivity, specificproduct SET transactivity.closeddatecust = '$val_INDEF', transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND (transactivity.closeddatecust IS NULL OR transactivity.closeddatecust = '0000-00-00') AND transactivity.locationid = '$clientLocId' AND transactivity.customerlocid = '$customerLocId' AND transactivity.type IN ('DE', 'PU', 'AD') AND transactivity.specificproductid = specificproduct.recid AND specificproduct.datex <= '$endingDate' AND specificproduct.productid IN ($prodList)");
			print "$sql\n" if ($debug);
			$dbh->do($sql) or die "$sql;\n";
		}

		$sql = $archObj->processSQL("SELECT COUNT(*) FROM transactivity ta, specificproduct sp WHERE ta.recid <= '$maxTaRecId' AND ta.type IN ('DE', 'PU', 'AD') AND (ta.closeddatecust IS NULL OR ta.closeddatecust = '0000-00-00') AND ta.specificproductid = sp.recid AND sp.datex <= '$endingDate' AND ta.customerlocid = '$customerLocId' AND ta.locationid = '$clientLocId'");
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my $isRecordExists = ($sth->fetchrow_array())[0];
		$sth->finish();


		
		
		
		if ($isRecordExists > 0) {
			$sql = "SELECT recid, billingflag, invdate FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND periodenddate = '$endingDate' AND type = 'I' AND source = 'T'";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my ($piRecId, $piBillingFlag, $invDate) = $sth->fetchrow_array();
			$sth->finish();

			if ((($piBillingFlag eq "Y" && $billingFlag eq "N") || $piBillingFlag eq "P") && length($piRecId) > 0 && $piRecId > 0) {
				next;
			}

			updateVendingLocs($clientLocId, $customerLocId, $endingDate);

			

			my $rows;
			my $PuRows;

				$sql = "SELECT DISTINCT(productid) FROM standarddraw WHERE customerlocid = '$customerLocId' AND clientlocid = '$clientLocId' AND effdt <= '$endingDate' ORDER BY effdt DESC";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my $refTempProductList = $sth->fetchall_arrayref();
				my @tempProductList = @{$refTempProductList};
				$sth->finish();
	
				my $fullProdListNew;
				my $fullProdList;
				my $lagWhereStrx;
				
								
				foreach my $tempProdCheckUpdate (@tempProductList) {
				
					
					my $isNExists;
					
					$sql = "SELECT COUNT(*) FROM specificproduct WHERE productid = '$tempProdCheckUpdate->[0]' AND datex <= '$endingDate' ";
						print "$sql\n;" if($debug);
						$sth = $dbh->prepare($sql);
						$sth->execute() or die "$sql;\n";
						$isNExists = $sth->fetchrow_array();
						$sth->finish();
					
	
					
					
						if($isNExists > 0) {
							$fullProdListNew .= length($fullProdListNew) == 0 ? $tempProdCheckUpdate->[0] : "," . $tempProdCheckUpdate->[0];
						}
					
				}
				
				if(length($fullProdListNew) > 0) {
					$fullProdList = $fullProdListNew;
				}
				
				print "fullProdList:$fullProdList\n" if ($debug);
				

				$fullProdList =~ s/,$|^,//g;
				$fullProdList =~ s/,,/,/g;
				print "fullProdList:$fullProdList\n" if ($debug);
my $PUlagWhereStr = '';
				
					# Both product exists so again add the excluded product list and lag product list to build the query
					$lagWhereStrx = "(specificproduct.productid IN ($fullProdList) AND specificproduct.datex <= '$endingDate')" . $lagWhereStrx;
					
					 $PUlagWhereStr = "(specificproduct.productid IN ($fullProdList) AND specificproduct.datex <= '$prvEndingDate')";
				
				
				print "lagWhereStr:$lagWhereStrx\n" if ($debug);
				
				
				print "\n\PU lagWhereStr:$PUlagWhereStr\n" if ($debug);
				
				
				
				if (length($piRecId) > 0) {
					my $qry1 = "UPDATE transactivity, specificproduct SET transactivity.closeddatecust = '". $runDate->getDate() ."',  transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.type IN ('DE',  'AD') AND (transactivity.closeddatecust IS NULL OR transactivity.closeddatecust = '0000-00-00' OR transactivity.closeddatecust = '$invDate') AND transactivity.specificproductid = specificproduct.recid AND transactivity.customerlocid = '$customerLocId' AND transactivity.locationid = '$clientLocId' ";
					if(length($lagWhereStrx) > 0) {
						$qry1 .= "AND ($lagWhereStrx) ";
					}
					$sql = $archObj->processSQL("$qry1");
					
					print "$sql\n" if ($debug);
				$rows = $dbh->do($sql) or die "$sql;\n";
				
					my $qry1 = "UPDATE transactivity, specificproduct SET transactivity.closeddatecust = '". $runDate->getDate() ."',  transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.type IN ('PU') AND (transactivity.closeddatecust IS NULL OR transactivity.closeddatecust = '0000-00-00' OR transactivity.closeddatecust = '$invDate') AND transactivity.specificproductid = specificproduct.recid AND transactivity.customerlocid = '$customerLocId' AND transactivity.locationid = '$clientLocId' ";
						if(length($PUlagWhereStr) > 0) {
							$qry1 .= "AND ($PUlagWhereStr) ";
						}
						$sql = $archObj->processSQL("$qry1");	
						print "$sql\n" if ($debug);
						 $PuRows   = $dbh->do($sql) or die "$sql;\n";
				
				
				} else {
					my $qry1 = "UPDATE transactivity, specificproduct SET transactivity.closeddatecust = '". $runDate->getDate() ."',  transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.type IN ('DE',  'AD') AND (transactivity.closeddatecust IS NULL OR transactivity.closeddatecust = '0000-00-00') AND transactivity.specificproductid = specificproduct.recid  AND transactivity.customerlocid = '$customerLocId' AND transactivity.locationid = '$clientLocId' ";
					if(length($lagWhereStrx) > 0) {
						$qry1 .= "AND ($lagWhereStrx) ";
					}
					$sql = $archObj->processSQL("$qry1");
					print "$sql\n" if ($debug);
					$rows = $dbh->do($sql) or die "$sql;\n";
					
					my $qry1 = "UPDATE transactivity, specificproduct SET transactivity.closeddatecust = '". $runDate->getDate() ."',  transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.type IN ('PU') AND (transactivity.closeddatecust IS NULL OR transactivity.closeddatecust = '0000-00-00') AND transactivity.specificproductid = specificproduct.recid AND transactivity.customerlocid = '$customerLocId' AND transactivity.locationid = '$clientLocId' ";
						if(length($PUlagWhereStr) > 0) {
							$qry1 .= "AND ($PUlagWhereStr) ";
						}
						$sql = $archObj->processSQL("$qry1");	
						print "$sql\n" if ($debug);
						 $PuRows = $dbh->do($sql) or die "$sql;\n";
						
						
				}
				
				
				
				
				# Finding LATEA exists or not
			my $charvar_LATEA = 'N';
			if($InvoiceMethod eq 'O')
			{
				$sql = "SELECT charvar FROM locationsystem WHERE recid = 'LATEA' AND locationid = '$clientLocId' AND (endeffdt = '0000-00-00' OR endeffdt IS NULL OR endeffdt > NOW())";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				 ($charvar_LATEA) = $sth->fetchrow_array();
				$sth->finish();
			}
			print "\ncharvar_LATEA:$charvar_LATEA\n";
			print "$rows > 0 || $PuRows > 0 ";	
				
				if (($rows > 0 || $PuRows > 0)&& length($dProdList) > 0) {

				my $pRows = 0;
				# Calculate the DE Amount
				$sql = $archObj->processSQL("SELECT COUNT(*), SUM(IF(ta.type = 'DE' OR ta.type = 'AD', ta.actquantity * ta.unitsales, 0)) as desum, SUM(IF(ta.type = 'PU', ta.actquantity * ta.unitsales, 0)) as pusum FROM transactivity ta, specificproduct sp WHERE ta.recid <= '$maxTaRecId' AND ta.customerlocid = '$customerLocId' AND ta.closeddatecust = '". $runDate->getDate() ."' AND ta.type IN ('DE', 'AD', 'PU') AND ta.locationid = '$clientLocId' AND ta.specificproductid = sp.recid AND sp.productid IN ($dProdList)");
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				($pRows, $deAmount, $puAmount) = $sth->fetchrow_array();
				$sth->finish();
				
				
				if ($pRows > 0) {

					$deAmount = sprintf("$format",$deAmount);

					$puAmount = sprintf("$format",$puAmount);

					$totalAmount = $deAmount - $puAmount;
					$totalAmount = sprintf("$format",$totalAmount);

					my $salesTaxAmount = 0;

					# NOW INSERT A RECORD INTO THE PRODUCTINVOICE FOR INVOICING
					
					
					if($charvar_LATEA eq 'Y')
					{
						# Finding LATEA exists or not
						$sql = "SELECT charvar FROM locationsystem WHERE recid = 'PPPMT' AND locationid = '$clientLocId' AND (endeffdt = '0000-00-00' OR endeffdt IS NULL OR endeffdt > NOW())";
						print "$sql\n" if ($debug);
						$sth = $dbh->prepare($sql);
						$sth->execute() or die "$sql;\n";
						my ($charvar_PPPMT) = $sth->fetchrow_array();
						$sth->finish();
						print "\ncharvar_PPPMT:$charvar_PPPMT\n";
						
						my $TmpStartDate = getStartingDate($period, $endingDate, $billPeriodDaycodeId, $billPeriodBaseDate);
						my $ReturnVal = 0 ;
						 $ReturnVal = callLATEAfunc($clientId,$TmpStartDate,$endingDate,$clientLocId, $customerLocId,$runDate->getDate(),$maxTaRecId,$dProdList,$charvar_PPPMT,$period,$billPeriodDaycodeId, $billPeriodBaseDate,$billingFlag);
						if(length(cvt_general::trim($ReturnVal)) > 1 && $ReturnVal != 0 )
						{
							my @tmpProdInvList = split(/~/, $ReturnVal);
							print "tmpProdInvList:" . "@tmpProdInvList" . "\n" if ($debug);
							foreach my $productInvoiceId (@tmpProdInvList) {
							
								if($NNBAT_Flag == 0 )
								{
									$sql = "SELECT intvar,charvar FROM locationsystem WHERE recid = \"NNBAT\" AND locationid = '$clientLocId' AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > now())";
									print "$sql\n"  if ($debug);
									$sth = $dbh->prepare($sql);
									$sth->execute() or die "Error in Query $DBI::errstr\n";
									  ($intvar_NNBAT,$charvar_NNBAT) = $sth->fetchrow_array();
									$sth->finish();
									if($charvar_NNBAT eq 'Y')
									{
										$sql = "UPDATE locationsystem SET intvar = intvar + 1 WHERE recid = \"NNBAT\" AND locationid = '$clientLocId' AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > now())";
										print "$sql\n" if ($debug);
										$dbh->do($sql) or die "$sql;\n";
									}
												
												$NNBAT_Flag = 1;
								}
								if($charvar_NNBAT eq 'Y')
								{
									createPostingTrack($clientLocId,$personid_PSTPR,'PMC',$productInvoiceId, $runDate->getDate(),$debug,$intvar_NNBAT);
								}	
							}
						}
						
					}
					my $_fromDate = "0000-00-00";
					my $ProdInvRecId = 0;
					if (length($piRecId) > 0 && $piRecId > 0) {
						$sql = "UPDATE productinvoice SET invdate = '". $runDate->getDate() ."', totalamount = '$totalAmount', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid = '$piRecId'";
						print "$sql\n" if ($debug);
						$dbh->do($sql) or die "$sql;\n";
						
						$ProdInvRecId = $piRecId;
						
						if ($piaFlag eq "Y") {
							$sql = "SELECT COUNT(*) FROM productinvoice WHERE periodenddate = '$endingDate' AND type = 'D' AND source = 'T' and clientlocid = '$clientLocId' AND customerlocid = '$customerLocId'";
							print "$sql\n" if ($debug);
							$sth = $dbh->prepare($sql);
							$sth->execute() or die "$sql;\n";
							my $duplicate = ($sth->fetchrow_array())[0];
							$sth->finish();

							if (!$duplicate) {
								print "sbz 1\n";
								print "cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerLocId $endingDate $billPeriodDaycodeId $_cutOffDate $customerEffDt $customerEndeffdt $_fromDate 0000-00-00 0 0 $called_from D T $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \r\n" if (1);
								system("cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerLocId $endingDate $billPeriodDaycodeId $_cutOffDate $customerEffDt $customerEndeffdt $_fromDate 0000-00-00 0 0 $called_from D T $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \&");
							}
							
						}
						
					} else {
						my $val_ADPMT = "0";
                                       		$sql = "SELECT DISTINCT(locationid) FROM locationsystem WHERE recid = 'ADPMT' AND locationid = $clientLocId AND charvar = 'Y' AND (endeffdt = '0000-00-00' OR endeffdt is null OR endeffdt > '". $runDate->getDate() ."')";
	                                        print "$sql\n" if ($debug);
	                                        $sth = $dbh->prepare($sql);
	                                        $sth->execute() or die "$sql;\n";
                                            $val_ADPMT = $sth->rows();
	                                        $sth->finish();

													$sql = "INSERT INTO productinvoice(clientlocid, customerlocid, type, invdate, periodenddate, totalamount, billingflag, source) values('$clientLocId', '$customerLocId', 'I', '". $runDate->getDate() ."', '$endingDate', '$totalAmount', '$billingFlag', 'T')";
													print "$sql\n" if ($debug);
													$dbh->do($sql) or die "$sql;\n";
													$ProdInvRecId = $dbh->{'mysql_insertid'};
													
						if ($piaFlag eq "Y") {
							print "sbz 2\n";
							print "cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerLocId $endingDate $billPeriodDaycodeId $_cutOffDate $customerEffDt $customerEndeffdt $_fromDate 0000-00-00 0 0 $called_from I T $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \r\n" if (1);
							system("cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerLocId $endingDate $billPeriodDaycodeId $_cutOffDate $customerEffDt $customerEndeffdt $_fromDate 0000-00-00 0 0 $called_from I T $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \&");
						}
													
											
												#$Se035Flg++;
												#$Se035ClientId = $clientId;
												#$Se035RunDate = $runDate->getDate();
												
												#print "\nFlg => $Se035Flg\nClientId => $Se035ClientId\n RunDate => $Se035RunDate\n";
											

                                                if($val_ADPMT > 0) {
	                                                my $val_PRODP = "0";
	                                                $sql = "SELECT realvar FROM locationsystem WHERE recid = 'PRODP' AND locationid = '$clientLocId' AND (endeffdt = '0000-00-00' OR endeffdt is null OR endeffdt > '". $runDate->getDate() ."')";
	                                                print "$sql\n" if ($debug);
	                                                $sth = $dbh->prepare($sql);
	                                                $sth->execute() or die "$sql;\n";
                                                        $val_PRODP = ($sth->fetchrow_array())[0];
	                                                $sth->finish();


	                                                $sql = "SELECT SUM(totalamount),periodenddate FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type IN('P','C') AND billingflag = 'Y' AND source = 'T' GROUP BY periodenddate";
	                                                print "$sql\n" if ($debug);
	                                                $sth = $dbh->prepare($sql);
	                                                $sth->execute() or die "$sql;\n";
			                                while (my ($chkTotalAmount,$periodenddate) = $sth->fetchrow_array()) {
													my $abschkTotalAmount = abs($chkTotalAmount);
													my $maxprodp = $abschkTotalAmount + $val_PRODP;
													my $minprodp = $abschkTotalAmount - $val_PRODP;

												    $sql = "UPDATE productinvoice SET billingflag = 'Y' WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type = 'I' AND source = 'T' AND periodenddate = '$periodenddate' ";
                                                    print "$sql\n" if ($debug);
                                                    $dbh->do($sql) or die "$sql;\n";

													$sql = "SELECT SUM(totalamount) FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type = 'I' AND billingflag = 'Y' AND source = 'T' AND totalamount < $maxprodp AND totalamount > $minprodp AND periodenddate = '$periodenddate' GROUP BY periodenddate";
	                                                print "$sql\n" if ($debug);
	                                                $sth = $dbh->prepare($sql);
	                                                $sth->execute() or die "$sql;\n";
													my $iexist = $sth->rows();


                                                        $chkTotalAmount = abs($chkTotalAmount);
                                                        if($iexist > 0) {

                                                        $sql = "UPDATE productinvoice SET billingflag = 'P' WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type IN('P','C') AND periodenddate = '$periodenddate' AND billingflag = 'Y' AND source = 'T'";
                                                        print "$sql\n" if ($debug);
                                                        $dbh->do($sql) or die "$sql;\n";

														$sql = "UPDATE productinvoice SET billingflag = 'P' WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type = 'I' AND billingflag = 'Y' AND source = 'T' AND periodenddate = '$periodenddate' ";
                                                        print "$sql\n" if ($debug);
                                                        $dbh->do($sql) or die "$sql;\n";
                                                       	}
                                                        }
                                                        $sth->finish();
                                               	}
					}
					my $InvoiceDate = $runDate->getDate();
					if($ProdInvRecId)
					{
						$Chk_AUBIL = 1; #Task#8460
						print "\nCall InvoicetaLink --->'transactivity','closeddatecust',$clientId,$clientLocId,$customerLocId,$InvoiceDate,$ProdInvRecId,$endingDate,'T','1','DE','PU'\n";
						
						cvt_general::createInvoiceTaLink($dbh,'transactivity','closeddatecust',$clientId,$clientLocId,$customerLocId,$InvoiceDate,$ProdInvRecId,$endingDate,'T','1',"'DE','PU'",'SE024',$dProdList,'');
					}
					#Task#8908 Start
					#Task#8938 Start
					#when an "I" record is created, the "D" record should become "E" so that it is not displayed in the PIA screen in TRA50, but it is accessible with the link from the Invoice Date field
					my $advInvRecord = 0;
					if ($piaFlag eq "Y") {
						$sql = "SELECT /*SE024*/ recid FROM productinvoice WHERE type = 'D' AND periodenddate = '$endingDate' AND clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND source = 'T'";
						print "$sql\n" if ($debug);
						$sth = $dbh->prepare($sql);
						$sth->execute() or die "$sql;\n";
						 $advInvRecord = ($sth->fetchrow_array())[0];
						$sth->finish();

						
					}
					if($val_SLSTX eq 'S')
					{
						print "\n val_SLSTX = 'S' So call CalculateSTax \n ";
						
						#CalculateSTax($dbh,$clientId,$clientLocId,$customerLocId,$InvoiceDate,$ProdInvRecId,$endingDate,'T',$dProdList); //Commented Task#8938
						
						if($advInvRecord > 0)
						{
							print "\n perl se/cm/calculatestax.pl SE024 $clientId $clientLocId $customerLocId $InvoiceDate $ProdInvRecId $endingDate T $dProdList H \n" if ($debug);
						system("perl se/cm/calculatestax.pl SE024 $clientId $clientLocId $customerLocId $InvoiceDate $ProdInvRecId $endingDate 'T' $dProdList H  \&");	exit;
							
						}else{
						print "\n perl se/cm/calculatestax.pl SE024 $clientId $clientLocId $customerLocId $InvoiceDate $ProdInvRecId $endingDate T $dProdList  \n" if ($debug);
						system("perl se/cm/calculatestax.pl SE024 $clientId $clientLocId $customerLocId $InvoiceDate $ProdInvRecId $endingDate T $dProdList  \&");	exit;		
						}
						
					}
					#Task#8908 Start
					
					
					if (length($advInvRecord) > 0 && $advInvRecord > 0) {
							$sql = "UPDATE productinvoice SET type = 'E', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid = '$advInvRecord'";
							print "$sql\n" if ($debug);
							$dbh->do($sql) or die "$sql;\n";
						}
					
					$invoicedPDEndDate .= length($invoicedPDEndDate) == 0 ? $endingDate : "," . $endingDate;
					#Task#8938 End
				}
			
				
			}
			if($rows > 0 && length($wProdList) > 0) {
				# Calculate the DE Amount
				my @wProdListArr = split(/,/, $wProdList);
				print "trying to create publisher invoice for products $wProdList\n" if($debug);

				my $pRows = 0;
				foreach my $publisherLocId (keys %publisherList) {

					my $wProdList = $publisherList{$publisherLocId};
					$sql = $archObj->processSQL("SELECT COUNT(*), SUM(IF(ta.type = 'DE' OR ta.type = 'AD', ta.actquantity * ta.unitsales, 0)) as desum, SUM(IF(ta.type = 'PU', ta.actquantity * ta.unitsales, 0)) as pusum FROM transactivity ta, specificproduct sp WHERE ta.recid <= '$maxTaRecId' AND ta.locationid = '$clientLocId' AND ta.customerlocid = '$customerLocId' AND ta.closeddatecust = '". $runDate->getDate() ."' AND ta.type IN ('DE', 'AD', 'PU') AND ta.specificproductid = sp.recid AND sp.productid IN ($wProdList)");
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					($pRows, $deAmount, $puAmount) = $sth->fetchrow_array();
					$sth->finish();

					if ($pRows > 0) {
						$deAmount = sprintf("$format",$deAmount);
						$puAmount = sprintf("$format",$puAmount);

						$totalAmount = $deAmount - $puAmount;
						$totalAmount = sprintf("$format",$totalAmount);

						# NOW INSERT A RECORD INTO THE PRODUCTINVOICE FOR INVOICING
						$sql = "SELECT recid FROM productinvoice WHERE clientlocid = '$publisherLocId' AND customerlocid = '$customerLocId' AND periodenddate = '$endingDate' AND type = 'I' AND source = 'T'";
						print "$sql\n" if ($debug);
						$sth = $dbh->prepare($sql);
						$sth->execute() or die "$sql;\n";
						my ($wPiRecId) = $sth->fetchrow_array();
						$sth->finish();
						 $ProdInvRecId = 0;
						my $_fromDate = "0000-00-00";
						if (length($wPiRecId) > 0 && $wPiRecId > 0) {
							$sql = "UPDATE productinvoice SET invdate = '". $runDate->getDate() ."',  totalamount = '$totalAmount', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid = '$wPiRecId'";
							print "$sql\n" if ($debug);
							$dbh->do($sql) or die "$sql;\n";
							$ProdInvRecId = $wPiRecId;
							if ($piaFlag eq "Y") {
								$sql = "SELECT COUNT(*) FROM productinvoice WHERE periodenddate = '$endingDate' AND type = 'D' AND source = 'T' and clientlocid = '$clientLocId' AND customerlocid = '$customerLocId'";
								print "$sql\n" if ($debug);
								$sth = $dbh->prepare($sql);
								$sth->execute() or die "$sql;\n";
								my $duplicate = ($sth->fetchrow_array())[0];
								$sth->finish();

								if (!$duplicate) {
									print "sbz 3\n";
									print "cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerLocId $endingDate $billPeriodDaycodeId $_cutOffDate $customerEffDt $customerEndeffdt $_fromDate 0000-00-00 0 0 $called_from D T $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \r\n" if (1);
									system("cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerLocId $endingDate $billPeriodDaycodeId $_cutOffDate $customerEffDt $customerEndeffdt $_fromDate 0000-00-00 0 0 $called_from D T $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \&");
								}
							}
						} else {
											my $val_ADPMT = "0";
                                       		$sql = "SELECT DISTINCT(locationid) FROM locationsystem WHERE recid = 'ADPMT' AND locationid = $clientLocId AND charvar = 'Y' AND (endeffdt = '0000-00-00' OR endeffdt is null OR endeffdt > '". $runDate->getDate() ."')";
	                                        print "$sql\n" if ($debug);
	                                        $sth = $dbh->prepare($sql);
	                                        $sth->execute() or die "$sql;\n";
                                               	$val_ADPMT = $sth->rows();
	                                        $sth->finish();

                                                $sql = "INSERT INTO productinvoice(clientlocid, customerlocid, type, invdate, periodenddate, totalamount, billingflag, source) values('$publisherLocId', '$customerLocId', 'I', '". $runDate->getDate() ."', '$endingDate', '$totalAmount', '$billingFlag', 'T')";
												print "$sql\n" if ($debug);
												$dbh->do($sql) or die "$sql;\n";
												$ProdInvRecId = $dbh->{'mysql_insertid'};
												#$Se035Flg++;
												#$Se035ClientId = $clientId;
												#$Se035RunDate = $runDate->getDate();
												if ($piaFlag eq "Y") {
													print "sbz 4\n";
													print "cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerLocId $endingDate $billPeriodDaycodeId $_cutOffDate $customerEffDt $customerEndeffdt $_fromDate 0000-00-00 0 0 $called_from I T $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \r\n" if (1);
													system("cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerLocId $endingDate $billPeriodDaycodeId $_cutOffDate $customerEffDt $customerEndeffdt $_fromDate 0000-00-00 0 0 $called_from I T $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \&");
												}
												#print "\nFlg => $Se035Flg\nClientId => $Se035ClientId\nRunDate => $Se035RunDate\n";
												

                                                if($val_ADPMT > 0) {
	                                                my $val_PRODP = "0";
	                                                $sql = "SELECT realvar FROM locationsystem WHERE recid = 'PRODP' AND locationid = '$clientLocId' AND (endeffdt = '0000-00-00' OR endeffdt is null OR endeffdt > '". $runDate->getDate() ."')";
	                                                print "$sql\n" if ($debug);
	                                                $sth = $dbh->prepare($sql);
	                                                $sth->execute() or die "$sql;\n";
                                                        $val_PRODP = ($sth->fetchrow_array())[0];
	                                                $sth->finish();


	                                                $sql = "SELECT SUM(totalamount),periodenddate FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type IN('P','C') AND billingflag = 'Y' AND source = 'T' GROUP BY periodenddate";
	                                                print "$sql\n" if ($debug);
	                                                $sth = $dbh->prepare($sql);
	                                                $sth->execute() or die "$sql;\n";
			                                while (my ($chkTotalAmount,$periodenddate) = $sth->fetchrow_array()) {
													my $abschkTotalAmount = abs($chkTotalAmount);
													my $maxprodp = $abschkTotalAmount + $val_PRODP;
													my $minprodp = $abschkTotalAmount - $val_PRODP;

													$sql = "UPDATE productinvoice SET billingflag = 'Y' WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type = 'I' AND source = 'T' AND periodenddate = '$periodenddate' ";
                                                    print "$sql\n" if ($debug);
                                                    $dbh->do($sql) or die "$sql;\n";

													$sql = "SELECT SUM(totalamount) FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type = 'I' AND billingflag = 'Y' AND source = 'T' AND totalamount < $maxprodp AND totalamount > $minprodp AND periodenddate = '$periodenddate' GROUP BY periodenddate";
	                                                print "$sql\n" if ($debug);
	                                                $sth = $dbh->prepare($sql);
	                                                $sth->execute() or die "$sql;\n";
													my $iexist = $sth->rows();


                                                        $chkTotalAmount = abs($chkTotalAmount);
                                                        if($iexist > 0) {

                                                        	my $locAmtDiff = $chkTotalAmount;

	                                                        $sql = "UPDATE productinvoice SET billingflag = 'P' WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type IN('P','C') AND periodenddate = '$periodenddate' AND billingflag = 'Y' AND source = 'T'";
	                                                        print "$sql\n" if ($debug);
	                                                        $dbh->do($sql) or die "$sql;\n";

															$sql = "UPDATE productinvoice SET billingflag = 'P' WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type = 'I' AND billingflag = 'Y' AND source = 'T' AND periodenddate = '$periodenddate' ";
															print "$sql\n" if ($debug);
															$dbh->do($sql) or die "$sql;\n";
                                                        	}
                                                                }
                                                        $sth->finish();
                                            	}
						}
						
						my $InvoiceDate = $runDate->getDate();
						if($ProdInvRecId)
						{
							$Chk_AUBIL = 1; #Task#8460
							print "\nCall InvoicetaLink --->'transactivity','closeddatecust',$clientId,$clientLocId,$customerLocId,$InvoiceDate,$ProdInvRecId,$endingDate,'T','1','DE','PU'\n";
							cvt_general::createInvoiceTaLink($dbh,'transactivity','closeddatecust',$clientId,$clientLocId,$customerLocId,$InvoiceDate,$ProdInvRecId,$endingDate,'T','1',"'DE','PU'",'SE024',$wProdList,$publisherLocId);
						}
						
					}
				}
			}
		
			
			
			
			
			
			
			
			
			
		}
	return $Chk_AUBIL; #Task#8460
	
}
sub processClient {

	my ($clientId, $clientLocId) = @_;
	if(length($clientId) == 0 || length ($clientLocId) == 0 || length($runDate->getDate()) == 0) {
		print "Not adequate data\n";
		return ;
	}

	# GETTING THE COMPANYID FROM THE LOCATIONSYSTEM  VMCPY
	# FOR THE VENDING MACHINE LOCATIONS
	$sql = "SELECT intvar FROM locationsystem WHERE recid = 'VMCPY' AND locationid = '$clientLocId' AND ( endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > '". $runDate->getDate() ."')";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $vmcpy = ($sth->fetchrow_array())[0];
	$sth->finish();

	if (length($vmcpy) == 0) {
		$vmcpy = 0;
	}
	#Task#8460 Start
	$sql = "SELECT /*SE024*/ intvar,charvar FROM locationsystem WHERE recid = 'AUBIL' AND locationid = '$clientLocId' AND charvar = 'Y' AND ( endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > '". $runDate->getDate() ."')";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my ($int_AUBIL,$char_AUBIL) = $sth->fetchrow_array();
	$sth->finish();

	if ($char_AUBIL eq 'Y' && (length($int_AUBIL) == 0 || $int_AUBIL == 0)) {
		$int_AUBIL = 3;
	}
	my $AUBIL_Flag = 0;
	#Task#8460 End
	
	my $full_Path = "/usr/local/apache/htdocs/twce/cm/";
	my $scriptName = "piafunc.php";
	my $called_from = "SE024";
	my $_cutOffDate = "0000-00-00";
	my $_RunDate = $runDate->getDate();
	
    #GETTING OLDUI TO DELETE NOT NEEDED RECORDS Task#389 Done By Chirag... Start
    $sql = "SELECT intvar FROM locationsystem WHERE recid = 'OLDUI' AND locationid = '$clientLocId' AND ( endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > '". $runDate->getDate() ."')";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $oldui = ($sth->fetchrow_array())[0];
	$sth->finish();

         if (length($oldui) == 0) {
		$oldui = 0;
	}

        if($oldui ne "0") {
			$sql = "Select recid  FROM productinvoice WHERE clientlocid = '$clientLocId' AND billingflag = 'N' AND invdate < DATE_SUB('". $runDate->getDate() ."' , INTERVAL $oldui DAY)";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my $DelInvRec = $sth->fetchall_arrayref();
			$sth->finish();
			my @DelInvRecArr = @{$DelInvRec};
			foreach my $record (@DelInvRecArr) {
				my ($DelInvRecId) = $record->[0];
				
				$sql = "DELETE FROM productinvoice WHERE clientlocid = '$clientLocId' AND recid = $DelInvRecId";
				print "$sql\n" if ($debug);
				$dbh->do($sql) or die "$sql;\n";
				
				cvt_general::DeleteInvoiceTaLink($dbh,$clientId,$clientLocId,$DelInvRecId,'SE024');
			}
        }
	
	#End Task#389
	
	my $NNBAT_Flag = 0;
	my $intvar_NNBAT = 0;
	my $charvar_NNBAT = 'N';
	
	$sql = "SELECT intvar FROM locationsystem WHERE locationid = '$clientLocId' AND recid = 'PSTPR' AND (endeffdt = '0000-00-00' OR endeffdt IS NULL OR endeffdt > now())";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $personid_PSTPR = ($sth->fetchrow_array())[0];
	$sth->finish();
	if($personid_PSTPR eq '' || length($personid_PSTPR) == 0)
	{
		$personid_PSTPR = 0;
	}	
	
	
	$sql = "SELECT /*se024*/ charvar FROM locationsystem WHERE locationid = '$clientLocId' AND recid = 'SUMTA' AND (endeffdt = '0000-00-00' OR endeffdt IS NULL OR endeffdt > now())";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my ($char_SUMTA) = $sth->fetchrow_array();
	$sth->finish();
	
	
	$sql = "( SELECT DISTINCT(l.recid), l.effdate, l.endeffdate FROM location l, locationlink ll, customerlink cl, company c WHERE cl.clientid = '$clientId' AND cl.clientlocid = '$clientLocId' AND cl.customerid = c.recid and ll.companyid = c.recid AND l.recid = ll.locationid AND l.effdate < '". $runDate->getDate() ."') UNION ( SELECT DISTINCT(l.recid), l.effdate, l.endeffdate FROM location l, company c, locationlink ll, vendinglocationlink vll WHERE  c.recid = '$vmcpy' AND ll.companyid = c.recid and l.recid = ll.locationid and vll.locationid = ll.locationid AND l.effdate < '". $runDate->getDate() ."')";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $refLocations = $sth->fetchall_arrayref();
	$sth->finish();
	
	my @custLocations = @{$refLocations};
	
	#my $Se035Flg = 0;
	#my $Se035ClientId = '';
	#my $Se035RunDate = '';
	
	foreach my $record (@custLocations) {
		my ($customerLocId, $customerEffDt, $customerEndeffdt) = @{$record};
		#my $customerLocId = $record->[0];
		if (length (cvt_general::trim($customerEndeffdt)) == 0) {
			$customerEndeffdt = '0000-00-00';
		}
		
		if (length (cvt_general::trim($customerLocId)) == 0) {
			$customerLocId = 0;
		}

		# CHECKING OF BILLINGDAYCODEID AND BILLINGPERIODDAYCODEID IN ROUTELINK
		# AND ALSO CHECK THAT TODAY IS BILLINGDAY OR NOT.
		# AND ALSO CALCULATE THE ENDINGDATE.

		$sql = "SELECT billingdaycodeid, billingperioddaycodeid, billingbasedate, billingperiodbasedate, piaflag, period ,invoicemethod  FROM routelink LEFT JOIN daycode dc on billingperioddaycodeid = dc.recid  WHERE clientid = '$clientId' and locationid = '$customerLocId' AND (billingdaycodeid IS NOT NULL AND billingdaycodeid > 0) AND (billingperioddaycodeid IS NOT NULL AND billingperioddaycodeid > 0) ";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my ($billDaycodeId, $billPeriodDaycodeId, $billBaseDate, $billPeriodBaseDate, $piaFlag, $billPeriodDaycodePeriod,$InvoiceMethod) = $sth->fetchrow_array();
		$sth->finish();
		
		print "$billDaycodeId, $billPeriodDaycodeId, $billBaseDate, $billPeriodBaseDate, $piaFlag, $billPeriodDaycodePeriod, $InvoiceMethod";
		
		if ($piaFlag eq "N") {
			print "PIA-FLG is N so Skipp\n";
			next ;
		}
		
		if($InvoiceMethod eq 'N')
		{
		  print " \n Don't process invoice \n";
		  next;
		}
		
		if (($billPeriodDaycodePeriod eq "B" || $billPeriodDaycodePeriod eq "J" || $billPeriodDaycodePeriod eq "K" || $billPeriodDaycodePeriod eq "L" || $billPeriodDaycodePeriod eq "X") && ($billPeriodBaseDate eq '0000-00-00' || $billPeriodBaseDate eq '') ) {
			print "When BillingPeriod = 'B' ,'J', K , L OR X BillingPeriodBaseDate must be set \n";
			
			cvt_general::error_log01("SE024","","","D059","2","0","$clientId","0","0","billingperiodbasedate Not Set for CustomerLocId:$customerLocId for billingperioddaycodeid = $billPeriodDaycodeId");
			next;			
		}
		
		my $isBillingDay = isLocationOpen($runDate->getDate(), $billDaycodeId, $billBaseDate, $billPeriodDaycodeId, $billPeriodBaseDate);
		
		print "\n\n isBillingDay:$isBillingDay \n\n";
		if ($isBillingDay == 0) {
			next ;
		}
		
		my $billingFlag = "N";
		if ($piaFlag eq "Y") {
			$billingFlag = "Y";
		}

		$sql = "SELECT type, period, sequence FROM daycode WHERE recid = '$billDaycodeId'";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my ($type, $period, $sequence) = $sth->fetchrow_array();
		$sth->finish();

		# WHEN TYPE IS "L" THEN CHANGE THE RUNDATE BACK TO THE RELATIVE DAYS FOR THE BILLINGDAYCODEID
		my $tempRunDate = '';
		
		
		print "\n\n type:$type \n\n ";
		if($type eq "L"){
			$tempRunDate = $runDate->getDate;
			# Finding the lagging period
			my $lag = $sequence * 7;
			$runDate->setDate($runDate->addDaysToDate($lag * -1));

		}
		
		$sql = "SELECT type, period, sequence FROM daycode WHERE recid = '$billPeriodDaycodeId'";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my ($billPaytype, $billPayperiod, $billPaysequence) = $sth->fetchrow_array();
		$sth->finish();
		
		
		if($billPaytype eq "T" || $billPaytype eq "C" || $type eq "E" || $type eq "O"){
			
			
			#Task#8460 Start
			
			$AUBIL_Flag = processClientLagReturn($clientId, $clientLocId, $customerLocId,$customerEffDt, $customerEndeffdt);
			
			 print "\n\n--------------------ClientLagRetur ENd------------------------\n\n";
			 if($AUBIL_Flag == 1 && $int_AUBIL > 0)
			{
				$sql = "UPDATE /*SE024*/ locationsystem SET datevar = CURDATE(), strvar = DATE_ADD(NOW(), INTERVAL $int_AUBIL HOUR) WHERE recid = 'AUBIL' AND locationid = '$clientLocId'";
				print "$sql\n" if ($debug);
				$dbh->do($sql) or die "$sql;\n"; 

				
				
				#Task#8532 Start
				$sql = "UPDATE /*SE024*/ locationsystem SET  strvar =  REPLACE(strvar, SUBSTRING_INDEX(strvar,'|',1) ,DATE_FORMAT( DATE_ADD(NOW(), INTERVAL $int_AUBIL HOUR),'%Y-%m-%d %H:%i:%s') ) WHERE recid = '38AUB' AND locationid = '$clientLocId'";
				print "$sql\n" if ($debug);
				$dbh->do($sql) or die "$sql;\n"; 
				#Task#8532 End
					#ClientSystem = SE024 cases, when the processing is complete for a client,
					# send an email to those listed in NotifyGroup "INV".
					# (Persons related by NotifyPerson.PersonLinkId where GroupCode = "INV")
					my @emailList;
					$sql = "SELECT /*SE024*/ p.email FROM personlink pl, person p, notifyperson np, notifygrouplink ngl WHERE ngl.groupcode = 'AUB' AND ngl.locationid = '$clientLocId' AND ngl.groupcode = np.groupcode AND np.personlinkid = pl.recid AND pl.locationid = ngl.locationid AND pl.personid = p.recid";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					while (my ($emailId) = $sth->fetchrow_array()) {
						push @emailList, $emailId;
					}
					$sth->finish();

					# Actually sending emails for notification.

					
					$sql = "SELECT /*SE024*/ DATE_FORMAT(DATE_ADD(ls1.strvar, INTERVAL ls2.intvar HOUR), '%m-%d-%y %r'),DATE_FORMAT(DATE_ADD(ls1.datevar, INTERVAL ls2.intvar HOUR), '%m-%d-%y') FROM locationsystem ls1, locationsystem ls2 WHERE ls2.recid = 'TIMEO' AND ls1.recid = 'AUBIL' AND ls2.locationid =  '$clientLocId' AND ls1.locationid = ls2.locationid ";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my ($formatedTime , $formatedDate) = $sth->fetchrow_array();
					$sth->finish();

					my $message = "";
					
					$message = "Customer invoices have been created with an invoice date $formatedDate.\n Please review them going to Data>>>Billing and Receiving, invoices will be automatically processed at $formatedTime\n";
						
					my $subject = "Customer Invoices created for $formatedDate";
					my $from = 'noreply@teakwce.com';

					foreach my $emailTo (@emailList) {
						my $email = MIME::Entity->build(From => "$from",
														  To       => "$emailTo",
														  Subject  => "$subject",
														  Data	   => "$message");
						eval{
							$email->smtpsend;
							print "Mail sent to $emailTo From $from\n";
						};
						if($@){
							print "Could Not Able to send email to $emailTo\n" if ($debug);
			 			}
					}
		
			}
			#Task#8460 End
		     next;
				
			
		} # end of lagging period condition.
	 
	
	

		my $endingDate;
		if($val_MANAR > 0) {
			$sql = "SELECT periodenddate FROM ".$archObj->archDB.".productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type = 'I' AND source = 'T' ORDER BY periodenddate DESC LIMIT 1";
			$sth = $dbh->prepare($sql);
			$sth->execute() || die "$sql;\n";
			my ($latestPDEndDate) = $sth->fetchrow_array();
			$sth->finish();

			print "latestPDEndDate = $latestPDEndDate\n" if($debug);

			if(length($latestPDEndDate) == 0) {
				$endingDate = getEndingDate($period, $runDate->getDate(), $billPeriodDaycodeId, $billPeriodBaseDate);
			} else {
				$latestPDEndDate = cvt_general::DateOperation($latestPDEndDate, 1, "ADD");
				print "latestPDStartDate = $latestPDEndDate\n" if($debug);
				my $nextPDEndDate = getFutureEndDateFromStartDate($latestPDEndDate, $billPeriodDaycodeId, $billPeriodBaseDate);
				print "latestPDEndDate = $nextPDEndDate\n" if($debug);
				if($nextPDEndDate gt $runDate->getDate()) {
					$latestPDEndDate = cvt_general::DateOperation($latestPDEndDate, 1, "SUB");
					$endingDate = $latestPDEndDate;
				} else {
					$endingDate = $nextPDEndDate;
				}
				print "EndDate = $endingDate\n" if($debug);
			}
		} else {
			print "isBillingDay9:$isBillingDay\nendingDate9:$endingDate\n" if($debug);
			
			$endingDate = getEndingDate($period, $runDate->getDate(), $billPeriodDaycodeId, $billPeriodBaseDate);
			print "isBillingDay:$isBillingDay \n endingDate:$endingDate\n" if($debug);
			
		  if ($isBillingDay =~ /-/) {
				$endingDate = $isBillingDay;
			}
		}

		print "sbz-endingDate = $endingDate\n" if($debug);

		if (length($endingDate) == 0) {
			#Billing date not found move to next product
			next ;
		}
		#Task#9196 Starts
		my $prevPeriodEndDate = getEndingDate("DummyVar", $runDate->getDate(), $billPeriodDaycodeId, $billPeriodBaseDate);
		
		my $prev_period_start_date = getStartingDate($billPayperiod, $endingDate, $billPeriodDaycodeId, $billPeriodBaseDate);
	
		my $currPeriodStartDate =  cvt_general::DateOperation($prevPeriodEndDate, 1, "ADD");
		my $currPeriodEndDate = getFutureEndDateFromStartDate($currPeriodStartDate, $billPeriodDaycodeId, $billPeriodBaseDate);

		print "$currPeriodStartDate < $customerEffDt\n" if($debug);
		if ($currPeriodStartDate lt $customerEffDt) {
			$currPeriodStartDate = $customerEffDt;
		}

		my $nextPeriodStartDate =  cvt_general::DateOperation($currPeriodEndDate, 1, "ADD");
		my $nextPeriodEndDate = getFutureEndDateFromStartDate($nextPeriodStartDate, $billPeriodDaycodeId, $billPeriodBaseDate);
		
		print "sbz ---- prev_period_start_date = $prev_period_start_date\n" if($debug);
		print "sbz ---- prevPeriodEndDate:$prevPeriodEndDate\n" if($debug);
		print "sbz ---- currPeriodStartDate = $currPeriodStartDate\n" if($debug);
		print "sbz ---- currPeriodEndDate = $currPeriodEndDate\n" if($debug);
		print "sbz ---- nextPeriodStartDate = $nextPeriodStartDate\n" if($debug);
		print "sbz ---- nextPeriodEndDate = $nextPeriodEndDate\n" if($debug);
		#exit 0;
		#Task#9196 Ends

		if (length($tempRunDate) > 0) {
			$runDate->setDate($tempRunDate);
			$tempRunDate = '';
		}

		# PROCESS OF THE TRANSACTION RECORDS FOR WHICH
		# CLOSEDCUSTDATE IS NULL OR ZERO.
		my $deAmount = 0;
		my $puAmount = 0;
		my $adAmount = 0;
		my $totalAmount = 0;

		$sql = "SELECT DISTINCT(productid) FROM standarddraw WHERE customerlocid = '$customerLocId' AND clientlocid = '$clientLocId' AND effdt <= '$endingDate' ORDER BY effdt DESC";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my $refTempProductList = $sth->fetchall_arrayref();
		my @tempProductList = @{$refTempProductList};
		$sth->finish();
		

		my $prodList = "";
		my $dProdList = "";
		my $wProdList = "";
		my %publisherList;
		foreach my $record (@tempProductList) {
			$sql = "SELECT COUNT(*) FROM product WHERE recid = '$record->[0]' /*AND producttype = 'PU' AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > '$endingDate')*/";
			$sth = $dbh->prepare($sql);
			$sth->execute() || die "$sql;\n";
			my $isValidProduct = ($sth->fetchrow_array())[0];
			$sth->finish();

			if($isValidProduct == 0) {
				next;
			}
			
			#my $startDate = getStartingDate($period, $endingDate, $billPeriodDaycodeId, $billPeriodBaseDate);
			
			$sql = "SELECT pricecodeid, invoicingent, invoicingentlocid  FROM standarddraw WHERE productid = '$record->[0]' AND customerlocid = '$customerLocId' AND clientlocid = '$clientLocId' AND effdt <= '$endingDate' /*AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > '$endingDate')*/ ORDER BY effdt DESC LIMIT 1";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my $isSDDrawExists = $sth->rows();
			my ($priceCodeId , $invEntity, $invEntLocId) = $sth->fetchrow_array();
			$sth->finish();

			# If no Effective StandardDraw exists then use the last deleted record based on PeriodEndDate
			if (!$isSDDrawExists) {
				$sql = "SELECT pricecodeid, invoicingent, invoicingentlocid  FROM standarddraw WHERE productid = '$record->[0]' AND customerlocid = '$customerLocId' AND clientlocid = '$clientLocId' AND effdt <= '$endingDate' ORDER BY effdt DESC LIMIT 1";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				($priceCodeId , $invEntity, $invEntLocId) = $sth->fetchrow_array();
				$sth->finish();
			}

			if (length($priceCodeId) == 0 || $priceCodeId == 0) {
				$prodList .= $record->[0] . ",";
			} else {
				if (length($invEntity) > 0 && $invEntity eq "W") {
					$wProdList .= "$record->[0]" . ",";
					if (length($invEntLocId) > 0 && $invEntLocId > 0) {
						if (not exists $publisherList{$invEntLocId}) {
							$publisherList{$invEntLocId} = "$record->[0]";
						} else {
							$publisherList{$invEntLocId} .= "," . "$record->[0]";
						}
					}
				} else {
					$dProdList .= "$record->[0]" . ",";
				}
			}
		}

		$dProdList =~ s/,$|^,//g;
		$dProdList =~ s/,,/,/g;
		$wProdList =~ s/,$|^,//g;
		$wProdList =~ s/,,/,/g;
		$prodList =~ s/,$|^,//g;
		$prodList =~ s/,,/,/g;

		print "dProdList:$dProdList\n" if($debug);
		print "wProdList:$wProdList\n" if($debug);
		print "prodList:$prodList\n" if($debug);

		

		if (length($prodList) > 0) {
			$sql = $archObj->processSQL("UPDATE transactivity, specificproduct SET transactivity.closeddatecust = '$val_INDEF', transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND (transactivity.closeddatecust IS NULL OR transactivity.closeddatecust = '0000-00-00') AND transactivity.locationid = '$clientLocId' AND transactivity.customerlocid = '$customerLocId' AND transactivity.type IN ('DE', 'PU', 'AD') AND transactivity.specificproductid = specificproduct.recid AND specificproduct.datex <= '$endingDate' AND specificproduct.productid IN ($prodList)");
			print "$sql\n" if ($debug);
			$dbh->do($sql) or die "$sql;\n";
		}

		$sql = $archObj->processSQL("SELECT COUNT(*) FROM transactivity ta, specificproduct sp WHERE ta.recid <= '$maxTaRecId' AND ta.type IN ('DE', 'PU', 'AD') AND (ta.closeddatecust IS NULL OR ta.closeddatecust = '0000-00-00') AND ta.specificproductid = sp.recid AND sp.datex <= '$endingDate' AND ta.customerlocid = '$customerLocId' AND ta.locationid = '$clientLocId'");
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my $isRecordExists = ($sth->fetchrow_array())[0];
		$sth->finish();


		
		# If $val_MANAR and No record found for old period then create the record for latest period
		if ($val_MANAR > 0  && $isRecordExists == 0) {
			$endingDate = getEndingDate($period, $runDate->getDate(), $billPeriodDaycodeId, $billPeriodBaseDate);
			print "endingDate = $endingDate\n" if($debug);

			if (length($endingDate) == 0) {
				#Billing date not found move to next product
				next ;
			}

			$sql = "SELECT DISTINCT(productid) FROM standarddraw WHERE customerlocid = '$customerLocId' AND clientlocid = '$clientLocId' AND effdt <= '$endingDate' ORDER BY effdt DESC";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my $refTempProductList = $sth->fetchall_arrayref();
			my @tempProductList = @{$refTempProductList};
			$sth->finish();

			$prodList = "";
			$dProdList = "";
			$wProdList = "";
			reset %publisherList;
			
			foreach my $record (@tempProductList) {
				$sql = "SELECT COUNT(*) FROM product WHERE recid = '$record->[0]' /*AND producttype = 'PU' AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > '$endingDate')*/";
				$sth = $dbh->prepare($sql);
				$sth->execute() || die "$sql;\n";
				my $isValidProduct = ($sth->fetchrow_array())[0];
				$sth->finish();

				if($isValidProduct == 0) {
					next;
				}
				my $startDate = '';
				#my $startDate = getStartingDate($period, $endingDate, $billPeriodDaycodeId, $billPeriodBaseDate);
				
				$sql = "SELECT pricecodeid, invoicingent, invoicingentlocid  FROM standarddraw WHERE productid = '$record->[0]' AND customerlocid = '$customerLocId' AND clientlocid = '$clientLocId' AND effdt <= '$endingDate' /*AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > '$startDate')*/ ORDER BY effdt DESC LIMIT 1";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my ($priceCodeId , $invEntity, $invEntLocId) = $sth->fetchrow_array();
				$sth->finish();

				if (length($priceCodeId) == 0 || $priceCodeId == 0) {
					$prodList .= $record->[0] . ",";
				} else {
					if (length($invEntity) > 0 && $invEntity eq "W") {
						$wProdList .= "$record->[0]" . ",";
						if (length($invEntLocId) > 0 && $invEntLocId > 0) {
							if (not exists $publisherList{$invEntLocId}) {
								$publisherList{$invEntLocId} = "$record->[0]";
							} else {
								$publisherList{$invEntLocId} .= "," . "$record->[0]";
							}
						}
					} else {
						$dProdList .= "$record->[0]" . ",";
					}
				}
			}

			$dProdList =~ s/,$|^,//g;
			$dProdList =~ s/,,/,/g;
			$wProdList =~ s/,$|^,//g;
			$wProdList =~ s/,,/,/g;
			$prodList =~ s/,$|^,//g;
			$prodList =~ s/,,/,/g;

			print "dProdList:$dProdList\n" if($debug);
			print "wProdList:$wProdList\n" if($debug);
			print "prodList:$prodList\n" if($debug);
			

			
			if (length($prodList) > 0) {
				$sql = $archObj->processSQL("UPDATE transactivity, specificproduct SET transactivity.closeddatecust = '$val_INDEF', transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND (transactivity.closeddatecust IS NULL OR transactivity.closeddatecust = '0000-00-00') AND transactivity.locationid = '$clientLocId' AND transactivity.customerlocid = '$customerLocId' AND transactivity.type IN ('DE', 'PU', 'AD') AND transactivity.locationid = '$clientLocId' AND transactivity.specificproductid = specificproduct.recid AND specificproduct.datex <= '$endingDate' AND specificproduct.productid IN ($prodList)");
				print "$sql\n" if ($debug);
				$dbh->do($sql) or die "$sql;\n";
			}

			$sql = $archObj->processSQL("SELECT COUNT(*) FROM transactivity ta, specificproduct sp WHERE ta.recid <= '$maxTaRecId' AND ta.type IN ('DE', 'PU', 'AD') AND (ta.closeddatecust IS NULL OR ta.closeddatecust = '0000-00-00') AND ta.specificproductid = sp.recid AND sp.datex <= '$endingDate' AND ta.customerlocid = '$customerLocId' AND ta.locationid = '$clientLocId'");
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			$isRecordExists = ($sth->fetchrow_array())[0];
			$sth->finish();
		}

		if ($isRecordExists > 0) {

#			$sql = "SELECT recid, billingflag FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND invdate = ". $runDate->getDate() ." AND periodenddate = '$endingDate' AND type = 'I' AND source = 'T'";
			$sql = "SELECT recid, billingflag, invdate FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND periodenddate = '$endingDate' AND type = 'I' AND source = 'T'";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my ($piRecId, $piBillingFlag, $invDate) = $sth->fetchrow_array();
			$sth->finish();

			if ((($piBillingFlag eq "Y" && $billingFlag eq "N") || $piBillingFlag eq "P") && length($piRecId) > 0 && $piRecId > 0) {
				next;
			}

			updateVendingLocs($clientLocId, $customerLocId, $endingDate);

			# Finding ARLAG exists or not
			$sql = "SELECT strvar FROM locationsystem WHERE recid = 'ARLAG' AND locationid = '$clientLocId' AND (endeffdt = '0000-00-00' OR endeffdt IS NULL OR endeffdt > NOW())";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my ($strvar_ARLAG) = $sth->fetchrow_array();
			$sth->finish();

			my $rows;
			if (length($strvar_ARLAG) > 0) {

				# ARLAG record found.
				my @prodStr = split(/\|/, $strvar_ARLAG);
				print "prodStr" . "@prodStr" , "\n" if ($debug);
				my $lagWhereStr;

				# Creating List of All the products which will be included in the invoice
				my @tmpFullProdList = split(/,/, $dProdList);
				print "tmpFullProdList:" . "@tmpFullProdList" . "\n" if ($debug);
				push @tmpFullProdList, split(/,/, $wProdList);
				print "tmpFullProdList:" . "@tmpFullProdList" . "\n" if ($debug);

				# Building the list of product and lag from the String of ARLAG
				my %lagProdList;
				foreach my $rec (@prodStr) {
					my ($key, $value) = split(/~/, $rec);
					$sql = "SELECT recid FROM product WHERE sdesc = '$key' AND clientid = '$clientId' AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > NOW())";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my ($prodId) = $sth->fetchrow_array();
					$sth->finish();
					if (length($prodId) > 0) {
						$lagProdList{$prodId} = $value;
					}
				}
				print "lagProdList:" if ($debug);
				print %lagProdList if ($debug);
				print "\n" if ($debug);

				# Excluding the LAG products from the full list and also building the
				# Where condition for the LAG products
				my $fullProdList;
				my $arlagNList;
				my $arlagRList;
				foreach my $val1 (@tmpFullProdList) {
					if (not exists $lagProdList{$val1}) {
						$fullProdList .= length($fullProdList) == 0 ? $val1 : "," . $val1;
					} else {
						if ($lagProdList{$val1} eq "N") {
							$arlagNList .= length($arlagNList) == 0 ? $lagProdList{$val1} : "," . $lagProdList{$val1};
						} elsif ($lagProdList{$val1} eq "R") {
							$arlagRList .= length($arlagRList) == 0 ? $lagProdList{$val1} : "," . $lagProdList{$val1};
						} else {
							$lagWhereStr .= " OR (specificproduct.productid = '".$val1."' AND specificproduct.datex <= DATE_SUB('$endingDate', INTERVAL ".$lagProdList{$val1}." DAY))";
						}
					}
				}

				print "lagWhereStr:$lagWhereStr\n" if ($debug);
				print "fullProdList:$fullProdList\n" if ($debug);
				print "arlagNList:$arlagNList\n" if ($debug);
				print "arlagRList:$arlagRList\n" if ($debug);

				$fullProdList =~ s/,$|^,//g;
				$fullProdList =~ s/,,/,/g;
				print "fullProdList:$fullProdList\n" if ($debug);
				
				my @tmpFullProdList1 = split(/,/, $fullProdList);
				print "tmpFullProdList1:" . "@tmpFullProdList1" . "\n" if ($debug);		
			
				my $fullProdListNew;
								
				foreach my $tempProdChecking (@tmpFullProdList1) {	

					my $isNExists;
					my $isKExists;
					my $isJExists;	
					my $startDate = getStartingDate($period, $endingDate, $billPeriodDaycodeId, $billPeriodBaseDate);
					
					$sql = "SELECT recid, productid, skedretn  FROM standarddraw WHERE productid = '$tempProdChecking' AND customerlocid = '$customerLocId' AND clientlocid = '$clientLocId' AND effdt <= '$endingDate' /*AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > '$startDate')*/ ORDER BY effdt DESC LIMIT 1";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my ($stdRecIdChk , $prodIdChk, $skedRetn) = $sth->fetchrow_array();
					my $stdRows = $dbh->do($sql) or die "$sql;\n";
					$sth->finish();
					
					
					
					if($skedRetn eq 'J')
					{
					$sql = "SELECT COUNT(*) FROM specificproduct WHERE productid = '$tempProdChecking' AND datex >= '$startDate' AND datex <= '$endingDate' ";
						print "$sql\n;" if($debug);
						$sth = $dbh->prepare($sql);
						$sth->execute() or die "$sql;\n";
						$isJExists = ($sth->fetchrow_array())[0];
						$sth->finish();
					}
					elsif($skedRetn eq 'K')
					{
					$sql = "SELECT COUNT(*) FROM specificproduct WHERE productid = '$tempProdChecking' AND skedretndate >= '$startDate' AND skedretndate <= '$endingDate' ";
						print "$sql\n;" if($debug);
						$sth = $dbh->prepare($sql);
						$sth->execute() or die "$sql;\n";
						$isKExists = ($sth->fetchrow_array())[0];
						$sth->finish();
					}
					else
					{
					$sql = "SELECT COUNT(*) FROM specificproduct WHERE productid = '$tempProdChecking' /*AND datex >= '$startDate' AND datex <= '$endingDate' */";
						print "$sql\n;" if($debug);
						$sth = $dbh->prepare($sql);
						$sth->execute() or die "$sql;\n";
						$isNExists = $sth->fetchrow_array();
						$sth->finish();
					}
						
										
					if ($stdRows > 0 && length($prodIdChk) > 0) {
						if($skedRetn eq 'J' && $isJExists > 0) {
							$lagWhereStr .= " OR (specificproduct.productid = '".$prodIdChk."' AND specificproduct.datex < '".$startDate."' AND (specificproduct.endeffdt IS NULL OR specificproduct.endeffdt = '0000-00-00'))";
						}
						elsif($skedRetn eq 'K' && $isKExists > 0) {
							$lagWhereStr .= " OR (specificproduct.productid = '".$prodIdChk."' AND specificproduct.skedretndate <= '".$endingDate."' AND specificproduct.skedretndate >= '".$startDate."' AND (specificproduct.endeffdt IS NULL OR specificproduct.endeffdt = '0000-00-00'))";
						}
						elsif($isNExists > 0) {
							$fullProdListNew .= length($fullProdListNew) == 0 ? $prodIdChk : "," . $prodIdChk;
						}
					}
				}				
								
				print "fullProdListNew:$fullProdListNew\n" if ($debug);
				if(length($fullProdListNew) gt 0) {
					$fullProdList = $fullProdListNew;
				}

				$fullProdList =~ s/,$|^,//g;
				$fullProdList =~ s/,,/,/g;
				print "fullProdList:$fullProdList\n" if ($debug);
				
				if (length($fullProdList) == 0) {
					# If all products are of LAG type then, modifiy the LAG where condition to properly build the query
					if (length($lagWhereStr) > 0) {
						$lagWhereStr = substr($lagWhereStr, 4);
					}
				} else {
					# Both product exists so again add the excluded product list and lag product list to build the query
					$lagWhereStr = "(specificproduct.productid IN ($fullProdList) AND specificproduct.datex <= '$endingDate')" . $lagWhereStr;
				}

				print "lagWhereStr:$lagWhereStr\n" if ($debug);
									
				if (length($piRecId) > 0) {
					my $qry1 = "UPDATE transactivity, specificproduct SET transactivity.closeddatecust = '". $runDate->getDate() ."',  transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.type IN ('DE', 'PU', 'AD') AND (transactivity.closeddatecust IS NULL OR transactivity.closeddatecust = '0000-00-00' OR transactivity.closeddatecust = '$invDate') AND transactivity.specificproductid = specificproduct.recid AND transactivity.customerlocid = '$customerLocId' AND transactivity.locationid = '$clientLocId' ";
					if(length($lagWhereStr) > 0) {
						$qry1 .= "AND ($lagWhereStr) ";
					}
					$sql = $archObj->processSQL("$qry1");
				} else {
					my $qry1 = "UPDATE transactivity, specificproduct SET transactivity.closeddatecust = '". $runDate->getDate() ."',  transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.type IN ('DE', 'PU', 'AD') AND (transactivity.closeddatecust IS NULL OR transactivity.closeddatecust = '0000-00-00') AND transactivity.specificproductid = specificproduct.recid AND transactivity.customerlocid = '$customerLocId' AND transactivity.locationid = '$clientLocId' ";
					if(length($lagWhereStr) > 0) {
						$qry1 .= "AND ($lagWhereStr) ";
					}
					$sql = $archObj->processSQL("$qry1");					
				}
				
				if(length($lagWhereStr) != 0) {
				print "$sql\n" if ($debug);
				$rows = $dbh->do($sql) or die "$sql;\n";
				}
				else {
				print "Location $customerLocId Skipped \n";
				next;
				}
				
				if (length($arlagNList) > 0) {
					# "Let's add a new feature the way that "ARLAG" works:
					# In addition to that, let's add the ability to set the "Lag in days" to be
				    # "N" meaning "Next Edition".  The way it would work is this: "
					# SD Based

					# Finding StartDate of Current Period
					my $startDate = getStartingDate($period, $endingDate, $billPeriodDaycodeId, $billPeriodBaseDate);
					print "startDate:$startDate\n" if ($debug);

					# Fining SpecificProducts between current period
					my $spIDList;
					$sql = "SELECT recid FROM specificproduct WHERE productid IN ($arlagNList) AND datex >= '$startDate' AND datex <= '$endingDate' AND (endeffdt IS NULL OR endeffdt = 0 OR endeffdt > '$endingDate')";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					while (my ($val) = $sth->fetchrow_array()) {
						$spIDList .= length($spIDList) == 0 ? $val : "," . $val;
					}
					$sth->finish();
					print "Current Period spIDList:$spIDList\n" if ($debug);

					# If SpecificProduct found then
					if (length($spIDList) > 0) {

						# Finding SpecificProduct for which transaction SD exists
						my @finalSPIdArr;
						$sql = $archObj->processSQL("SELECT transactivity.specificproductid FROM transactivity WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.specificproductid IN ($spIDList) AND transactivity.type = 'SD' AND transactivity.customerlocid = '$customerLocId' AND transactivity.locationid = '$clientLocId'");
						print "$sql\n" if ($debug);
						$sth = $dbh->prepare($sql);
						$sth->execute() or die "$sql;\n";
						while (my ($val) = $sth->fetchrow_array()) {
							push @finalSPIdArr, $val;
						}
						$sth->finish();
						print "Final SPID List" if ($debug);
						print "@finalSPIdArr" . "\n" if ($debug);


						# Finding Previous Issue of such Product
						my $finalSPIdStr;
						foreach my $tempSPId (@finalSPIdArr) {
							$sql = "SELECT sp1.recid FROM specificproduct sp, specificproduct sp1 WHERE sp.recid = '$tempSPId' AND sp.productid = sp1.productid AND sp1.datex < sp.datex ORDER BY sp1.datex DESC LIMIT 1";
							print "$sql\n" if ($debug);
							$sth = $dbh->prepare($sql);
							$sth->execute() or die "$sql;\n";
							my ($prevSPId) = $sth->fetchrow_array();
							$sth->finish();

							$finalSPIdStr .= length($finalSPIdStr) == 0 ? $prevSPId : "," . $prevSPId;

						}

						$finalSPIdStr = 0 if (length($finalSPIdStr) == 0);

						print "Previous Issue SPID List : finalSPIdStr:$finalSPIdStr\n" if ($debug);
						# Considering records in billing for those previous issues
						if (length($piRecId) > 0) {
							$sql = $archObj->processSQL("UPDATE transactivity SET transactivity.closeddatecust = '". $runDate->getDate() ."',  transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.type IN ('DE', 'PU', 'AD') AND (transactivity.closeddatecust IS NULL OR transactivity.closeddatecust = '0000-00-00' OR transactivity.closeddatecust = '$invDate') AND transactivity.specificproductid IN ($finalSPIdStr) AND transactivity.customerlocid = '$customerLocId' AND transactivity.locationid = '$clientLocId'");
						} else {
							$sql = $archObj->processSQL("UPDATE transactivity SET transactivity.closeddatecust = '". $runDate->getDate() ."',  transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.type IN ('DE', 'PU', 'AD') AND (transactivity.closeddatecust IS NULL OR transactivity.closeddatecust = '0000-00-00') AND transactivity.specificproductid IN ($finalSPIdStr) AND transactivity.customerlocid = '$customerLocId' AND transactivity.locationid = '$clientLocId'");
						}
						print "$sql\n" if ($debug);
						$rows = $dbh->do($sql) or die "$sql;\n";

					}

				}
				if (length($arlagRList) > 0) {
					# In addition to that, let's add the ability to set the "Lag in days" to be
					# "R" meaning "Scheduled Return".  The way it would work is this: "
					# SP Based

					# Finding StartDate of Current Period
					my $startDate = getStartingDate($period, $endingDate, $billPeriodDaycodeId, $billPeriodBaseDate);
					print "startDate:$startDate\n" if ($debug);

					# Fining SpecificProduct beteen current period
					my $spIDList;
					$sql = $archObj->processSQL("SELECT DISTINCT ta.specificproductid FROM transactivity ta, specificproduct sp WHERE ta.locationid = '$clientLocId' AND ta.customerlocid = '$customerLocId' AND ta.datet >= '$startDate' AND ta.datet <= '$endingDate' AND ta.type = 'SP' AND ta.specificproductid = sp.recid AND sp.productid IN ($arlagNList) AND (sp.endeffdt IS NULL OR sp.endeffdt = 0 OR sp.endeffdt > '$endingDate')");
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					while (my ($val) = $sth->fetchrow_array()) {
						$spIDList .= length($spIDList) == 0 ? $val : "," . $val;
					}
					$sth->finish();
					print "Current Period spIDList:$spIDList\n" if ($debug);

					# If SpecificProduct found then
					if (length($spIDList) > 0) {

						print "SPID List : spIDList:$spIDList\n" if ($debug);
						# Considering records in billing for those previous issues
						if (length($piRecId) > 0) {
							$sql = $archObj->processSQL("UPDATE transactivity SET transactivity.closeddatecust = '". $runDate->getDate() ."',  transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.type IN ('DE', 'PU', 'AD') AND (transactivity.closeddatecust IS NULL OR transactivity.closeddatecust = '0000-00-00' OR transactivity.closeddatecust = '$invDate') AND transactivity.specificproductid IN ($spIDList) AND transactivity.customerlocid = '$customerLocId' AND transactivity.locationid = '$clientLocId'");
						} else {
							$sql = $archObj->processSQL("UPDATE transactivity SET transactivity.closeddatecust = '". $runDate->getDate() ."',  transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.type IN ('DE', 'PU', 'AD') AND (transactivity.closeddatecust IS NULL OR transactivity.closeddatecust = '0000-00-00') AND transactivity.specificproductid IN ($spIDList) AND transactivity.customerlocid = '$customerLocId' AND transactivity.locationid = '$clientLocId'");
						}
						print "$sql\n" if ($debug);
						$rows = $dbh->do($sql) or die "$sql;\n";

					}
				}

			} else {
#Changes related to skedretn J and K implementation started			

				$sql = "SELECT DISTINCT(productid) FROM standarddraw WHERE customerlocid = '$customerLocId' AND clientlocid = '$clientLocId' AND effdt <= '$endingDate' ORDER BY effdt DESC";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my $refTempProductList = $sth->fetchall_arrayref();
				my @tempProductList = @{$refTempProductList};
				$sth->finish();
	
				my $fullProdListNew;
				my $fullProdList;
				my $lagWhereStrx;
				
								
				foreach my $tempProdCheckUpdate (@tempProductList) {
				
					my $isJExists;
					my $isKExists;
					my $isNExists;
					my $startDate = getStartingDate($period, $endingDate, $billPeriodDaycodeId, $billPeriodBaseDate);
					
					$sql = "SELECT recid, productid, skedretn  FROM standarddraw WHERE productid = '$tempProdCheckUpdate->[0]' AND customerlocid = '$customerLocId' AND clientlocid = '$clientLocId' AND effdt <= '$endingDate' /*AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > '$startDate')*/ ORDER BY effdt DESC LIMIT 1";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my ($stdRecIdChk , $prodIdChk, $skedRetn) = $sth->fetchrow_array();
					my $stdRows = $dbh->do($sql) or die "$sql;\n";
					$sth->finish();
					
				
					
					if($skedRetn eq 'J')
					{
					$sql = "SELECT COUNT(*) FROM specificproduct WHERE productid = '$tempProdCheckUpdate->[0]' AND datex >= '$startDate' AND datex <= '$endingDate' ";
						print "$sql\n;" if($debug);
						$sth = $dbh->prepare($sql);
						$sth->execute() or die "$sql;\n";
						$isJExists = $sth->fetchrow_array();
						$sth->finish();
					}
					elsif($skedRetn eq 'K')
					{
					$sql = "SELECT COUNT(*) FROM specificproduct WHERE productid = '$tempProdCheckUpdate->[0]' AND skedretndate >= '$startDate' AND skedretndate <= '$endingDate' ";
						print "$sql\n;" if($debug);
						$sth = $dbh->prepare($sql);
						$sth->execute() or die "$sql;\n";
						$isKExists = $sth->fetchrow_array();
						$sth->finish();
					}
					else
					{
					$sql = "SELECT COUNT(*) FROM specificproduct WHERE productid = '$tempProdCheckUpdate->[0]' /*AND datex >= '$startDate'*/ AND datex <= '$endingDate' ";
						print "$sql\n;" if($debug);
						$sth = $dbh->prepare($sql);
						$sth->execute() or die "$sql;\n";
						$isNExists = $sth->fetchrow_array();
						$sth->finish();
					}
	
					
					if ($stdRows > 0 && length($prodIdChk) > 0) {
						if($skedRetn eq 'J' && $isJExists > 0) {
							$lagWhereStrx .= " OR (specificproduct.productid = '".$prodIdChk."' AND specificproduct.datex < '".$startDate."' AND (specificproduct.endeffdt IS NULL OR specificproduct.endeffdt = '0000-00-00'))";
						}
						elsif($skedRetn eq 'K' && $isKExists > 0) {
							$lagWhereStrx .= " OR (specificproduct.productid = '".$prodIdChk."' AND specificproduct.skedretndate <= '".$endingDate."' AND specificproduct.skedretndate >= '".$startDate."' AND (specificproduct.endeffdt IS NULL OR specificproduct.endeffdt = '0000-00-00'))";
						}
						elsif($isNExists > 0) {
							$fullProdListNew .= length($fullProdListNew) == 0 ? $prodIdChk : "," . $prodIdChk;
						}
					}
				}
				
				if(length($fullProdListNew) > 0) {
					$fullProdList = $fullProdListNew;
				}
				
				print "fullProdList:$fullProdList\n" if ($debug);
				

				$fullProdList =~ s/,$|^,//g;
				$fullProdList =~ s/,,/,/g;
				print "fullProdList:$fullProdList\n" if ($debug);

				if (length($fullProdList) == 0) {
					# If all products are of LAG type then, modifiy the LAG where condition to properly build the query
					if (length($lagWhereStrx) > 0) {
						$lagWhereStrx = substr($lagWhereStrx, 4);
					}
				} else {
					# Both product exists so again add the excluded product list and lag product list to build the query
					$lagWhereStrx = "(specificproduct.productid IN ($fullProdList) AND specificproduct.datex <= '$endingDate')" . $lagWhereStrx;
				}

				print "lagWhereStr:$lagWhereStrx\n" if ($debug);
				
				
#Changes related to skedretn J and K implementation end - more changes in update queries				
				
				if (length($piRecId) > 0) {
					my $qry1 = "UPDATE transactivity, specificproduct SET transactivity.closeddatecust = '". $runDate->getDate() ."',  transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.type IN ('DE', 'PU', 'AD') AND (transactivity.closeddatecust IS NULL OR transactivity.closeddatecust = '0000-00-00' OR transactivity.closeddatecust = '$invDate') AND transactivity.specificproductid = specificproduct.recid AND transactivity.customerlocid = '$customerLocId' AND transactivity.locationid = '$clientLocId' ";
					if(length($lagWhereStrx) > 0) {
						$qry1 .= "AND ($lagWhereStrx) ";
					}
					$sql = $archObj->processSQL("$qry1");
				} else {
					my $qry1 = "UPDATE transactivity, specificproduct SET transactivity.closeddatecust = '". $runDate->getDate() ."',  transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.type IN ('DE', 'PU', 'AD') AND (transactivity.closeddatecust IS NULL OR transactivity.closeddatecust = '0000-00-00') AND transactivity.specificproductid = specificproduct.recid  AND transactivity.customerlocid = '$customerLocId' AND transactivity.locationid = '$clientLocId' ";
					if(length($lagWhereStrx) > 0) {
						$qry1 .= "AND ($lagWhereStrx) ";
					}
					$sql = $archObj->processSQL("$qry1");
				}
				print "$sql\n" if ($debug);
				$rows = $dbh->do($sql) or die "$sql;\n";
			}
			
			# Finding LATEA exists or not
			my $charvar_LATEA = 'N';
			if($InvoiceMethod eq 'O')
			{
				$sql = "SELECT charvar FROM locationsystem WHERE recid = 'LATEA' AND locationid = '$clientLocId' AND (endeffdt = '0000-00-00' OR endeffdt IS NULL OR endeffdt > NOW())";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				 ($charvar_LATEA) = $sth->fetchrow_array();
				$sth->finish();
			}
			print "\ncharvar_LATEA:$charvar_LATEA\n";
			
			
			
			my $advInvRecord = 0; #Task#8938 
			
			if ($rows > 0 && length($dProdList) > 0) {

				my $pRows = 0;
				# Calculate the DE Amount
				$sql = $archObj->processSQL("SELECT COUNT(*), SUM(IF(ta.type = 'DE' OR ta.type = 'AD', ta.actquantity * ta.unitsales, 0)) as desum, SUM(IF(ta.type = 'PU', ta.actquantity * ta.unitsales, 0)) as pusum FROM transactivity ta, specificproduct sp WHERE ta.recid <= '$maxTaRecId' AND ta.customerlocid = '$customerLocId' AND ta.closeddatecust = '". $runDate->getDate() ."' AND ta.type IN ('DE', 'AD', 'PU') AND ta.locationid = '$clientLocId' AND ta.specificproductid = sp.recid AND sp.productid IN ($dProdList)");
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				($pRows, $deAmount, $puAmount) = $sth->fetchrow_array();
				$sth->finish();
				
				
				if ($pRows > 0) {

					$deAmount = sprintf("$format",$deAmount);

					$puAmount = sprintf("$format",$puAmount);

					$totalAmount = $deAmount - $puAmount;
					$totalAmount = sprintf("$format",$totalAmount);

					my $salesTaxAmount = 0;

#					if ($val_SLSTX eq "S") {
#						$sql = "SELECT salestaxsetid FROM location WHERE recid = '$customerLocId' AND salestaxsetid IS NOT NULL AND salestaxsetid > 0";
#						print "$sql\n" if ($debug);
#						$sth = $dbh->prepare($sql);
#						$sth->execute() or die "$sql;\n";
#						my ($salesTaxSetId) = $sth->fetchrow_array();
#						$sth->finish();
#
#						if (length($salesTaxSetId) > 0) {
#
#							$sql = "SELECT salestaxid FROM salestaxlink WHERE salestaxsetid = '$salesTaxSetId' AND productinvoicesource = 'T' AND ORDER BY effdt <= '$endingDate' AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > NOW()) ORDER BY effdt DESC LIMIT 1";
#							print "$sql\n" if ($debug);
#							$sth = $dbh->prepare($sql);
#							$sth->execute() or die "$sql;\n";
#							my ($salesTaxId) = $sth->fetchrow_array();
#							$sth->finish();
#
#
#							if (length($salesTaxId) > 0) {
#								$sql = "SELECT percent FROM salestaxpercent WHERE salestaxid = '$salesTaxId' AND effdt <= '$endingDate' AND ";
#								print "$sql\n" if ($debug);
#								$sth = $dbh->prepare($sql);
#								$sth->execute() or die "$sql;\n";
#								my () = $sth->fetchrow_array();
#								$sth->finish();
#							}
#							$sql = "SELECT stp.percent FROM salestaxset sts, salestaxlink stl , salestax st, salestaxpercent stp WHERE sts.clientid = '$clientId' AND (sts.endeffdt IS NULL OR sts.endeffdt = '0000-00-00' OR sts.endeffdt > NOW()) AND sts.recid = stl.salestaxsetid AND stl.productinvoicesource = 'T' AND (stl.endeffdt IS NULL OR stl.endeffdt = '0000-00-00' OR stl.endeffdt > NOW()) AND stl.salestaxid = st.recid AND st.clientid = sts.clientid AND st.producttype = 'PU' AND (st.endeffdt IS NULL OR st.endeffdt = '0000-00-00' OR st.endeffdt > NOW())";
#							print "$sql\n" if ($debug);
#							$sth = $dbh->prepare($sql);
#							$sth->execute() or die "$sql;\n";
#							my () = $sth->fetchrow_array();
#							$sth->finish();
#						}
#
#					} elsif ($val_SLSTX eq "L") {
#					} elsif ($val_SLSTX eq "H") {
#					}

					# NOW INSERT A RECORD INTO THE PRODUCTINVOICE FOR INVOICING
					if($charvar_LATEA eq 'Y')
					{
						# Finding LATEA exists or not
						$sql = "SELECT charvar FROM locationsystem WHERE recid = 'PPPMT' AND locationid = '$clientLocId' AND (endeffdt = '0000-00-00' OR endeffdt IS NULL OR endeffdt > NOW())";
						print "$sql\n" if ($debug);
						$sth = $dbh->prepare($sql);
						$sth->execute() or die "$sql;\n";
						my ($charvar_PPPMT) = $sth->fetchrow_array();
						$sth->finish();
						print "\ncharvar_PPPMT:$charvar_PPPMT\n";
						
						my $TmpStartDate = getStartingDate($period, $endingDate, $billPeriodDaycodeId, $billPeriodBaseDate);
						my $ReturnVal = 0 ;
						 $ReturnVal = callLATEAfunc($clientId,$TmpStartDate,$endingDate,$clientLocId, $customerLocId,$runDate->getDate(),$maxTaRecId,$dProdList,$charvar_PPPMT,$period,$billPeriodDaycodeId, $billPeriodBaseDate,$billingFlag);
						if(length(cvt_general::trim($ReturnVal)) > 1 && $ReturnVal != 0 )
						{
							my @tmpProdInvList = split(/~/, $ReturnVal);
							print "tmpProdInvList:" . "@tmpProdInvList" . "\n" if ($debug);
							foreach my $productInvoiceId (@tmpProdInvList) {
							
								if($NNBAT_Flag == 0 )
								{
									$sql = "SELECT intvar,charvar FROM locationsystem WHERE recid = \"NNBAT\" AND locationid = '$clientLocId' AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > now())";
									print "$sql\n"  if ($debug);
									$sth = $dbh->prepare($sql);
									$sth->execute() or die "Error in Query $DBI::errstr\n";
									  ($intvar_NNBAT,$charvar_NNBAT) = $sth->fetchrow_array();
									$sth->finish();
									if($charvar_NNBAT eq 'Y')
									{
										$sql = "UPDATE locationsystem SET intvar = intvar + 1 WHERE recid = \"NNBAT\" AND locationid = '$clientLocId' AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > now())";
										print "$sql\n" if ($debug);
										$dbh->do($sql) or die "$sql;\n";
									}
												
												$NNBAT_Flag = 1;
								}
								if($charvar_NNBAT eq 'Y')
								{
									createPostingTrack($clientLocId,$personid_PSTPR,'PMC',$productInvoiceId, $runDate->getDate(),$debug,$intvar_NNBAT);
								}	
							}
						}
						
					}
					my $_fromDate = "0000-00-00";
					my $ProdInvRecId = 0;
					if (length($piRecId) > 0 && $piRecId > 0) {
						$sql = "UPDATE productinvoice SET invdate = '". $runDate->getDate() ."', totalamount = '$totalAmount', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid = '$piRecId'";
						print "$sql\n" if ($debug);
						$dbh->do($sql) or die "$sql;\n";
						
						 $ProdInvRecId = $piRecId;
						
						
						if ($piaFlag eq "Y") {
							$sql = "SELECT COUNT(*) FROM ".$archObj->archDB.".productinvoice WHERE periodenddate = '$endingDate' AND type = 'D' AND source = 'T' and clientlocid = '$clientLocId' AND customerlocid = '$customerLocId'";
							print "$sql\n" if ($debug);
							$sth = $dbh->prepare($sql);
							$sth->execute() or die "$sql;\n";
							my $duplicate = ($sth->fetchrow_array())[0];
							$sth->finish();

							if (!$duplicate) {
								print "sbz 5\n";
								print "cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerLocId $endingDate $billPeriodDaycodeId $_cutOffDate $customerEffDt $customerEndeffdt $_fromDate 0000-00-00 0 0 $called_from D T $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \r\n" if (1);
								system("cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerLocId $endingDate $billPeriodDaycodeId $_cutOffDate $customerEffDt $customerEndeffdt $_fromDate 0000-00-00 0 0 $called_from D T $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \&");
							}
							
						}
						
					} else {
						my $val_ADPMT = "0";
						$sql = "SELECT DISTINCT(locationid) FROM locationsystem WHERE recid = 'ADPMT' AND locationid = $clientLocId AND charvar = 'Y' AND (endeffdt = '0000-00-00' OR endeffdt is null OR endeffdt > '". $runDate->getDate() ."')";
						print "$sql\n" if ($debug);
						$sth = $dbh->prepare($sql);
						$sth->execute() or die "$sql;\n";
						$val_ADPMT = $sth->rows();
						$sth->finish();

						$sql = "INSERT INTO productinvoice(clientlocid, customerlocid, type, invdate, periodenddate, totalamount, billingflag, source) values('$clientLocId', '$customerLocId', 'I', '". $runDate->getDate() ."', '$endingDate', '$totalAmount', '$billingFlag', 'T')";
						print "$sql\n" if ($debug);
						$dbh->do($sql) or die "$sql;\n";
						$ProdInvRecId = $dbh->{'mysql_insertid'};
													
						if ($piaFlag eq "Y") {
							#print "sbz 6\n";
							#print "cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerLocId $endingDate $billPeriodDaycodeId $_cutOffDate $customerEffDt $customerEndeffdt $_fromDate 0000-00-00 0 0 $called_from I T $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \r\n" if (1);
							#system("cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerLocId $endingDate $billPeriodDaycodeId $_cutOffDate $customerEffDt $customerEndeffdt $_fromDate 0000-00-00 0 0 $called_from I T $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \&");
							
							##point 2
							# P C sum - ta sum = finalSUm -> create 'C' record
							
							#finding the sum of paid + credit amount for the current period
							$sql = "SELECT SUM(totalamount) FROM ".$archObj->archDB.".productinvoice WHERE periodenddate = '$endingDate' AND type IN ('P', 'C') AND clientlocid = '$clientLocId' AND customerlocid = '$customerLocId'";
							print "$sql\n" if ($debug);
							$sth = $dbh->prepare($sql);
							$sth->execute() or die "$sql;\n";
							my $currPIAPaidAmount = ($sth->fetchrow_array())[0];
							$sth->finish();
							if (length($currPIAPaidAmount) == 0) {
								# no paid or credit amount so no amount to transfer and hence moving to next location
								next;
							}
							
							my $productIds = "";
							$sql = "SELECT DISTINCT(sd.productid) FROM standarddraw sd, product p WHERE sd.customerlocid = '$customerLocId' AND sd.clientlocid = '$clientLocId' AND sd.effdt <= '$prevPeriodEndDate' AND (sd.endeffdt IS NULL OR sd.endeffdt = '0000-00-00' OR sd.endeffdt > '$currPeriodStartDate') AND p.recid = sd.productid /*AND p.producttype = 'PU'*/ AND (p.endeffdt IS NULL OR p.endeffdt = '0000-00-00' OR p.endeffdt > '$prevPeriodEndDate')";
							print "$sql\n" if ($debug);
							$sth = $dbh->prepare($sql);
							$sth->execute() or die "$sql;\n";
							while (my $row = ($sth->fetchrow_array())[0]) {
								if ($productIds eq "") {
									$productIds = $row;
								} else {
									$productIds .= "," . $row;
								}
							}
							$sth->finish();

							$productIds =~ s/^,//;
							
							# finding the total actual amount from start to cutoff date
							my $specificProductIds = "";
							my $currActAmount = 0;
							
							if (length($productIds) > 0) {
								$sql = "SELECT DISTINCT(recid) FROM ".$archObj->archDB.".specificproduct WHERE datex >= '$prev_period_start_date' AND datex <=  '$prevPeriodEndDate' AND productid IN ($productIds) AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt < '$prevPeriodEndDate')";
								print "$sql\n" if ($debug);
								$sth = $dbh->prepare($sql);
								$sth->execute() or die "$sql;\n";
								while (my $row = ($sth->fetchrow_array())[0]) {
									if ($specificProductIds eq "") {
										$specificProductIds = $row;
									} else {
										$specificProductIds .= "," . $row;
									}
								}
								$sth->finish();
								$specificProductIds =~ s/^,//;
							}#END if (length($productIds) > 0)
							
							if (length($specificProductIds) > 0) {
								# DE + AD amount
								$sql = $archObj->processSQL("SELECT SUM(actquantity * unitsales) as desum FROM transactivity WHERE type IN ('DE', 'AD') AND closeddatecust = '". $runDate->getDate() ."' AND specificproductid IN ($specificProductIds) AND customerlocid = '$customerLocId' AND locationid = '$clientLocId'");
								print "$sql\n" if ($debug);
								$sth = $dbh->prepare($sql);
								$sth->execute() or die "$sql;\n";
								my $deAmount = sprintf("$format",($sth->fetchrow_array())[0]);
								$sth->finish();
								print "deAmount:$deAmount\n" if ($debug);

								# PU amount
								$sql = $archObj->processSQL("SELECT SUM(actquantity * unitsales) as pusum FROM transactivity WHERE type = 'PU' AND closeddatecust = '". $runDate->getDate() ."' AND specificproductid IN ($specificProductIds) AND customerlocid = '$customerLocId' AND locationid = '$clientLocId'");
								print "$sql\n" if ($debug);
								$sth = $dbh->prepare($sql);
								$sth->execute() or die "$sql;\n";
								my $puAmount = sprintf("$format",($sth->fetchrow_array())[0]);
								$sth->finish();
								if (length (cvt_general::trim($puAmount)) == 0) {
									$puAmount = 0;
								}
								print "puAmount:$puAmount\n" if ($debug);

								$currActAmount = $deAmount - $puAmount;
								print "currActAmount:$currActAmount\n" if ($debug);
								$currActAmount = sprintf("$format",$currActAmount);
							}
							print "currActAmount:$currActAmount\n" if ($debug);
							
							my $creditAmount = $currActAmount - abs($currPIAPaidAmount);
							print "creditAmount:$creditAmount\n" if ($debug);
							
							# allowed tolerance limit
							$sql = "SELECT realvar FROM locationsystem WHERE recid = 'PRODP' AND locationid = '$clientLocId'";
							print "$sql\n" if ($debug);
							$sth = $dbh->prepare($sql);
							$sth->execute() or die "$sql;\n";
							my $real_PRODP = ($sth->fetchrow_array())[0];
							$sth->finish();
							my $ntive_PRODP = -1 * $real_PRODP;
							
							print "real_PRODP:$real_PRODP\n" if ($debug);
							print "ntive_PRODP:$ntive_PRODP\n" if ($debug);
							print "$creditAmount <= $real_PRODP && $creditAmount >= $ntive_PRODP\n" if ($debug);
							
							if($creditAmount <= $real_PRODP && $creditAmount >= $ntive_PRODP) {
								next;
							}
							my @dispPrevPeriodEndDate = split(/-/, $prevPeriodEndDate);
							my $tempPrevPeriodEndDate = sprintf("%02d/%02d/%02d", $dispPrevPeriodEndDate[1], ,$dispPrevPeriodEndDate[2], $dispPrevPeriodEndDate[0] - 2000);
							
							my @dispCurrPeriodEndDate = split(/-/, $currPeriodEndDate);
							my $tempCurrPeriodEndDate = sprintf("%02d/%02d/%02d", $dispCurrPeriodEndDate[1], $dispCurrPeriodEndDate[2], $dispCurrPeriodEndDate[0] - 2000);
							
							my $current_C_amt = -1 * $creditAmount;
							
							$sql = "SELECT billingflag FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND periodenddate = '$prevPeriodEndDate' AND type = 'I' AND source = 'T'";
							print "$sql\n" if ($debug);
							$sth = $dbh->prepare($sql);
							$sth->execute() or die "$sql;\n";
							my $pi_billingflag = ($sth->fetchrow_array())[0];
							$sth->finish();
							
							$sql = "INSERT INTO productinvoice (clientlocid, customerlocid, type, source, invdate, periodenddate, totalamount, comment, billingflag) VALUES ('$clientLocId', '$customerLocId', 'C', 'T', '". $runDate->getDate() ."', '$prevPeriodEndDate', '$current_C_amt', 'Transfer to Period Ending: $tempCurrPeriodEndDate', '$pi_billingflag')";
							print "$sql\n" if ($debug);
							$dbh->do($sql) or die "$sql;\n";
							my $productInvoiceId = $dbh->{'mysql_insertid'};
							if($productInvoiceId) {
								if($char_SUMTA eq 'Y') {
									cvt_general::insertInvoiceTaLinkProductInvoice($dbh, $clientId, $clientLocId, $customerLocId, '', 'T', 'C', $prevPeriodEndDate, $runDate->getDate(), $productInvoiceId, 'SE024');
								}
							}

							
							# creating new credit record for next billing period
							$sql = "SELECT billingflag FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND periodenddate = '$currPeriodEndDate' AND type = 'I' AND source = 'T'";
							print "$sql\n" if ($debug);
							$sth = $dbh->prepare($sql);
							$sth->execute() or die "$sql;\n";
							my $pi_billingflag = ($sth->fetchrow_array())[0];
							$sth->finish();
							
							$sql = "INSERT INTO productinvoice (clientlocid, customerlocid, type, source, invdate, periodenddate, totalamount, comment, billingflag) VALUES ('$clientLocId', '$customerLocId', 'C', 'T', '". $runDate->getDate() ."', '$currPeriodEndDate', '$creditAmount', 'Transfer From Period Ending: $tempPrevPeriodEndDate', '$pi_billingflag')";
							print "$sql\n" if ($debug);
							$dbh->do($sql) or die "$sql;\n";
							my $productInvoiceId1 = $dbh->{'mysql_insertid'};
							if($productInvoiceId1) {
								if($char_SUMTA eq 'Y') {
									cvt_general::insertInvoiceTaLinkProductInvoice($dbh, $clientId, $clientLocId, $customerLocId, '', 'T', 'C', $currPeriodEndDate, $runDate->getDate(), $productInvoiceId1, 'SE024');
								}
							}
							
							system("perl se/cm/tra50_archdata.pl $clientId FORCECOPY");
							
						}
													
											
												#$Se035Flg++;
												#$Se035ClientId = $clientId;
												#$Se035RunDate = $runDate->getDate();
												
												#print "\nFlg => $Se035Flg\nClientId => $Se035ClientId\n RunDate => $Se035RunDate\n";
											

                                                if($val_ADPMT > 0) {
	                                                my $val_PRODP = "0";
	                                                $sql = "SELECT realvar FROM locationsystem WHERE recid = 'PRODP' AND locationid = '$clientLocId' AND (endeffdt = '0000-00-00' OR endeffdt is null OR endeffdt > '". $runDate->getDate() ."')";
	                                                print "$sql\n" if ($debug);
	                                                $sth = $dbh->prepare($sql);
	                                                $sth->execute() or die "$sql;\n";
                                                        $val_PRODP = ($sth->fetchrow_array())[0];
	                                                $sth->finish();


	                                                $sql = "SELECT SUM(totalamount),periodenddate FROM ".$archObj->archDB.".productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type IN('P','C') AND billingflag = 'Y' AND source = 'T' AND periodenddate = '$endingDate'";
	                                                print "$sql\n" if ($debug);
	                                                $sth = $dbh->prepare($sql);
	                                                $sth->execute() or die "$sql;\n";
			                                #while () {
											
													my ($chkTotalAmount,$periodenddate) = $sth->fetchrow_array();
													my $abschkTotalAmount = abs($chkTotalAmount);
													my $maxprodp = $abschkTotalAmount + $val_PRODP;
													my $minprodp = $abschkTotalAmount - $val_PRODP;
												if(length($periodenddate) > 1)
												{
												    $sql = "UPDATE productinvoice SET billingflag = 'Y'  WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type = 'I' AND source = 'T' AND periodenddate = '$periodenddate' ";
                                                    print "$sql\n" if ($debug);
                                                    $dbh->do($sql) or die "$sql;\n";
													
													 $sql = "UPDATE ".$archObj->archDB.".productinvoice SET billingflag = 'Y'  WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type = 'I' AND source = 'T' AND periodenddate = '$periodenddate' ";
                                                    print "$sql\n" if ($debug);
                                                    $dbh->do($sql) or die "$sql;\n";

													$sql = "SELECT SUM(totalamount) FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type = 'I' AND billingflag = 'Y' AND source = 'T' AND totalamount < $maxprodp AND totalamount > $minprodp AND periodenddate = '$periodenddate' GROUP BY periodenddate";
	                                                print "$sql\n" if ($debug);
	                                                $sth = $dbh->prepare($sql);
	                                                $sth->execute() or die "$sql;\n";
													my $iexist = $sth->rows();
													
												if(!$iexist)
												{												
													$sql = "SELECT SUM(totalamount) FROM ".$archObj->archDB.".productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type = 'I' AND billingflag = 'Y' AND source = 'T' AND totalamount < $maxprodp AND totalamount > $minprodp AND periodenddate = '$periodenddate' GROUP BY periodenddate";
	                                                print "$sql\n" if ($debug);
	                                                $sth = $dbh->prepare($sql);
	                                                $sth->execute() or die "$sql;\n";
													 $iexist = $sth->rows();
												}

                                                        $chkTotalAmount = abs($chkTotalAmount);
                                                        if($iexist > 0) {

                                                        # $sql = "UPDATE productinvoice SET billingflag = 'P' WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type IN('P','C') AND periodenddate = '$periodenddate' AND billingflag = 'Y' AND source = 'T'";
                                                        # print "$sql\n" if ($debug);
                                                        # $dbh->do($sql) or die "$sql;\n";

														$sql = "UPDATE productinvoice SET billingflag = 'P', archupdt = IF(archupdt = 'P', 'U', archupdt)  WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' /*AND type = 'I'*/ AND billingflag = 'Y' AND source = 'T' AND periodenddate = '$periodenddate' ";
                                                        print "$sql\n" if ($debug);
                                                        $dbh->do($sql) or die "$sql;\n";
														
														$sql = "UPDATE ".$archObj->archDB.".productinvoice SET billingflag = 'P'  WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' /*AND type = 'I'*/ AND billingflag = 'Y' AND source = 'T' AND periodenddate = '$periodenddate' ";
                                                        print "$sql\n" if ($debug);
                                                        $dbh->do($sql) or die "$sql;\n";
                                                       	}
                                                        #}
                                                        $sth->finish();
													}	
                                               	}
					}
					
					my $InvoiceDate = $runDate->getDate();
				    if($ProdInvRecId)
					{
						
						$AUBIL_Flag = 1; #Task#8460
						print "\nCall InvoicetaLink --->'transactivity','closeddatecust',$clientId,$clientLocId,$customerLocId,$InvoiceDate,$ProdInvRecId,$endingDate,'T','1','DE','PU' $dProdList\n";
						cvt_general::createInvoiceTaLink($dbh,'transactivity','closeddatecust',$clientId,$clientLocId,$customerLocId,$InvoiceDate,$ProdInvRecId,$endingDate,'T','1',"'DE','PU'",'SE024',$dProdList,'');
					}
					#Task#8908 Start
					#Task#8938 Start
					if ($piaFlag eq "Y") {
				
					
						$sql = "SELECT /*SE024*/ recid FROM ".$archObj->archDB.".productinvoice WHERE type = 'D' AND periodenddate = '$endingDate' AND clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND source = 'T'";
						print "$sql\n" if ($debug);
						$sth = $dbh->prepare($sql);
						$sth->execute() or die "$sql;\n";
						 $advInvRecord = ($sth->fetchrow_array())[0];
						$sth->finish();

					
					}
					
					print "\n val_SLSTX:$val_SLSTX \n ";
					if($val_SLSTX eq 'S')
					{
						print "\n val_SLSTX = 'S' So call CalculateSTax \n ";
						
						#CalculateSTax($dbh,$clientId,$clientLocId,$customerLocId,$InvoiceDate,$ProdInvRecId,$endingDate,'T',$dProdList); Commented Task#8938 logic shifted 
						
						
						if($advInvRecord)
						{
							print "perl se/cm/calculatestax.pl SE024 $clientId $clientLocId $customerLocId $InvoiceDate $ProdInvRecId $endingDate T $dProdList H"  if ($debug);
							system("perl se/cm/calculatestax.pl SE024 $clientId $clientLocId $customerLocId $InvoiceDate $ProdInvRecId $endingDate T $dProdList H  \&");	
							
						}else
						{						
							print "perl se/cm/calculatestax.pl SE024 $clientId $clientLocId $customerLocId $InvoiceDate $ProdInvRecId $endingDate T $dProdList" if ($debug);
							system("perl se/cm/calculatestax.pl SE024 $clientId $clientLocId $customerLocId $InvoiceDate $ProdInvRecId $endingDate T $dProdList  \&");					            
						}
						#Task#8938 End
					}
					#Task#8908 End
					$invoicedPDEndDate .= length($invoicedPDEndDate) == 0 ? $endingDate : "," . $endingDate;
					
				}

				#when an "I" record is created, the "D" record should become "E" so that it is not displayed in the PIA screen in TRA50, but it is accessible with the link from the Invoice Date field
				

					if (length($advInvRecord) > 0 && $advInvRecord > 0) {
						$sql = "UPDATE productinvoice SET type = 'E', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid = '$advInvRecord'";
						print "$sql\n" if ($debug);
						$dbh->do($sql) or die "$sql;\n";
						
						$sql = "UPDATE ".$archObj->archDB.".productinvoice SET type = 'E' WHERE recid = '$advInvRecord'";
						print "$sql\n" if ($debug);
						$dbh->do($sql) or die "$sql;\n";
					}
				
			}
			if($rows > 0 && length($wProdList) > 0) {
				# Calculate the DE Amount
				my @wProdListArr = split(/,/, $wProdList);
				print "trying to create publisher invoice for products $wProdList\n" if($debug);

				my $pRows = 0;
				foreach my $publisherLocId (keys %publisherList) {

					my $wProdList = $publisherList{$publisherLocId};
					$sql = $archObj->processSQL("SELECT COUNT(*), SUM(IF(ta.type = 'DE' OR ta.type = 'AD', ta.actquantity * ta.unitsales, 0)) as desum, SUM(IF(ta.type = 'PU', ta.actquantity * ta.unitsales, 0)) as pusum FROM transactivity ta, specificproduct sp WHERE ta.recid <= '$maxTaRecId' AND ta.locationid = '$clientLocId' AND ta.customerlocid = '$customerLocId' AND ta.closeddatecust = '". $runDate->getDate() ."' AND ta.type IN ('DE', 'AD', 'PU') AND ta.specificproductid = sp.recid AND sp.productid IN ($wProdList)");
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					($pRows, $deAmount, $puAmount) = $sth->fetchrow_array();
					$sth->finish();

					if ($pRows > 0) {
						$deAmount = sprintf("$format",$deAmount);
						$puAmount = sprintf("$format",$puAmount);

						$totalAmount = $deAmount - $puAmount;
						$totalAmount = sprintf("$format",$totalAmount);

						# NOW INSERT A RECORD INTO THE PRODUCTINVOICE FOR INVOICING
						$sql = "SELECT recid FROM productinvoice WHERE clientlocid = '$publisherLocId' AND customerlocid = '$customerLocId' AND periodenddate = '$endingDate' AND type = 'I' AND source = 'T'";
						print "$sql\n" if ($debug);
						$sth = $dbh->prepare($sql);
						$sth->execute() or die "$sql;\n";
						my ($wPiRecId) = $sth->fetchrow_array();
						$sth->finish();
						my $ProdInvRecId = 0;
						my $_fromDate = "0000-00-00";
						if (length($wPiRecId) > 0 && $wPiRecId > 0) {
							$sql = "UPDATE productinvoice SET invdate = '". $runDate->getDate() ."',  totalamount = '$totalAmount', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid = '$wPiRecId'";
							print "$sql\n" if ($debug);
							$dbh->do($sql) or die "$sql;\n";
							
							$ProdInvRecId = $wPiRecId;
							
							if ($piaFlag eq "Y") {
								$sql = "SELECT COUNT(*) FROM productinvoice WHERE periodenddate = '$endingDate' AND type = 'D' AND source = 'T' and clientlocid = '$clientLocId' AND customerlocid = '$customerLocId'";
								print "$sql\n" if ($debug);
								$sth = $dbh->prepare($sql);
								$sth->execute() or die "$sql;\n";
								my $duplicate = ($sth->fetchrow_array())[0];
								$sth->finish();
								if(!$duplicate)
								{
									$sql = "SELECT COUNT(*) FROM ".$archObj->archDB.".productinvoice WHERE periodenddate = '$endingDate' AND type = 'D' AND source = 'T' and clientlocid = '$clientLocId' AND customerlocid = '$customerLocId'";
									print "$sql\n" if ($debug);
									$sth = $dbh->prepare($sql);
									$sth->execute() or die "$sql;\n";
									 $duplicate = ($sth->fetchrow_array())[0];
									$sth->finish();
								}
								if (!$duplicate) {
									print "sbz 7\n";
									print "cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerLocId $endingDate $billPeriodDaycodeId $_cutOffDate $customerEffDt $customerEndeffdt $_fromDate 0000-00-00 0 0 $called_from D T $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \r\n" if (1);
									system("cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerLocId $endingDate $billPeriodDaycodeId $_cutOffDate $customerEffDt $customerEndeffdt $_fromDate 0000-00-00 0 0 $called_from D T $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \&");
								}
							}
						} else {
											my $val_ADPMT = "0";
                                       		$sql = "SELECT DISTINCT(locationid) FROM locationsystem WHERE recid = 'ADPMT' AND locationid = $clientLocId AND charvar = 'Y' AND (endeffdt = '0000-00-00' OR endeffdt is null OR endeffdt > '". $runDate->getDate() ."')";
	                                        print "$sql\n" if ($debug);
	                                        $sth = $dbh->prepare($sql);
	                                        $sth->execute() or die "$sql;\n";
                                               	$val_ADPMT = $sth->rows();
	                                        $sth->finish();

                                                $sql = "INSERT INTO productinvoice(clientlocid, customerlocid, type, invdate, periodenddate, totalamount, billingflag, source) values('$publisherLocId', '$customerLocId', 'I', '". $runDate->getDate() ."', '$endingDate', '$totalAmount', '$billingFlag', 'T')";
												print "$sql\n" if ($debug);
												$dbh->do($sql) or die "$sql;\n";
												$ProdInvRecId = $dbh->{'mysql_insertid'};
												#$Se035Flg++;
												#$Se035ClientId = $clientId;
												#$Se035RunDate = $runDate->getDate();
												if ($piaFlag eq "Y") {
													print "sbz 8\n";
													print "cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerLocId $endingDate $billPeriodDaycodeId $_cutOffDate $customerEffDt $customerEndeffdt $_fromDate 0000-00-00 0 0 $called_from I T $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \r\n" if (1);
													system("cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerLocId $endingDate $billPeriodDaycodeId $_cutOffDate $customerEffDt $customerEndeffdt $_fromDate 0000-00-00 0 0 $called_from I T $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \&");
												}
												#print "\nFlg => $Se035Flg\nClientId => $Se035ClientId\nRunDate => $Se035RunDate\n";
												

                                                if($val_ADPMT > 0) {
	                                                my $val_PRODP = "0";
	                                                $sql = "SELECT realvar FROM locationsystem WHERE recid = 'PRODP' AND locationid = '$clientLocId' AND (endeffdt = '0000-00-00' OR endeffdt is null OR endeffdt > '". $runDate->getDate() ."')";
	                                                print "$sql\n" if ($debug);
	                                                $sth = $dbh->prepare($sql);
	                                                $sth->execute() or die "$sql;\n";
                                                        $val_PRODP = ($sth->fetchrow_array())[0];
	                                                $sth->finish();


	                                                $sql = "SELECT SUM(totalamount),periodenddate FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type IN('P','C') AND billingflag = 'Y' AND source = 'T' AND periodenddate = '$endingDate' ";
	                                                print "$sql\n" if ($debug);
	                                                $sth = $dbh->prepare($sql);
	                                                $sth->execute() or die "$sql;\n";
			                                #while () { 
											
													my ($chkTotalAmount,$periodenddate) = $sth->fetchrow_array();
													
													if(length($periodenddate) == 0)
													{
														 $sql = "SELECT SUM(totalamount),periodenddate FROM ".$archObj->archDB.".productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type IN('P','C') AND billingflag = 'Y' AND source = 'T' AND periodenddate = '$endingDate' ";
														print "$sql\n" if ($debug);
														$sth = $dbh->prepare($sql);
														$sth->execute() or die "$sql;\n";						
														($chkTotalAmount,$periodenddate) = $sth->fetchrow_array();
													}
													
													
													my $abschkTotalAmount = abs($chkTotalAmount);
													my $maxprodp = $abschkTotalAmount + $val_PRODP;
													my $minprodp = $abschkTotalAmount - $val_PRODP;
												if(length($periodenddate) > 1)
												{
													$sql = "UPDATE productinvoice SET billingflag = 'Y', archupdt = IF(archupdt = 'P', 'U', archupdt)  WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type = 'I' AND source = 'T' AND periodenddate = '$periodenddate' ";
                                                    print "$sql\n" if ($debug);
                                                    $dbh->do($sql) or die "$sql;\n";
													
													 $sql = "UPDATE ".$archObj->archDB.".productinvoice SET billingflag = 'Y' WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type = 'I' AND source = 'T' AND periodenddate = '$periodenddate' ";
                                                    print "$sql\n" if ($debug);
                                                    $dbh->do($sql) or die "$sql;\n";

													$sql = "SELECT SUM(totalamount) FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type = 'I' AND billingflag = 'Y' AND source = 'T' AND totalamount < $maxprodp AND totalamount > $minprodp AND periodenddate = '$periodenddate' GROUP BY periodenddate";
	                                                print "$sql\n" if ($debug);
	                                                $sth = $dbh->prepare($sql);
	                                                $sth->execute() or die "$sql;\n";
													my $iexist = $sth->rows();
													
													if(!$iexist)
													{
														$sql = "SELECT SUM(totalamount) FROM ".$archObj->archDB.".productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type = 'I' AND billingflag = 'Y' AND source = 'T' AND totalamount < $maxprodp AND totalamount > $minprodp AND periodenddate = '$periodenddate' GROUP BY periodenddate";
														print "$sql\n" if ($debug);
														$sth = $dbh->prepare($sql);
														$sth->execute() or die "$sql;\n";
														 $iexist = $sth->rows();
													}

                                                        $chkTotalAmount = abs($chkTotalAmount);
                                                        if($iexist > 0) {

                                                        	my $locAmtDiff = $chkTotalAmount;


															$sql = "UPDATE productinvoice SET billingflag = 'P', archupdt = IF(archupdt = 'P', 'U', archupdt)  WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' /*AND type = 'I'*/ AND billingflag = 'Y' AND source = 'T' AND periodenddate = '$periodenddate' ";
															print "$sql\n" if ($debug);
															$dbh->do($sql) or die "$sql;\n";
															
															
															$sql = "UPDATE ".$archObj->archDB.".productinvoice SET billingflag = 'P' WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' /*AND type = 'I'*/ AND billingflag = 'Y' AND source = 'T' AND periodenddate = '$periodenddate' ";
															print "$sql\n" if ($debug);
															$dbh->do($sql) or die "$sql;\n";
                                                        	}
                                                               # }
                                                        $sth->finish();
													}	
                                            	}
						}
						 my $InvoiceDate = $runDate->getDate();
						   if($ProdInvRecId)
							{
								$AUBIL_Flag = 1; #Task#8460
								print "\nCall InvoicetaLink --->'transactivity','closeddatecust',$clientId,$clientLocId,$publisherLocId,$customerLocId,$InvoiceDate,$ProdInvRecId,$endingDate,'T','1','DE','PU'\n";
								cvt_general::createInvoiceTaLink($dbh,'transactivity','closeddatecust',$clientId,$clientLocId,$customerLocId,$InvoiceDate,$ProdInvRecId,$endingDate,'T','1',"'DE','PU'",'SE024',$wProdList,$publisherLocId);
							}
					}
				}
			}
		}
	}
	
	#Task#8460 Start
	if($AUBIL_Flag == 1 && $int_AUBIL > 0)
	{
		$sql = "UPDATE /*SE024*/ locationsystem SET datevar = CURDATE(), strvar = DATE_ADD(NOW(), INTERVAL $int_AUBIL HOUR) WHERE recid = 'AUBIL' AND locationid = '$clientLocId'";
		print "$sql\n" if ($debug);
		$dbh->do($sql) or die "$sql;\n"; 
		
		#Task#8532 Start
		$sql = "UPDATE /*SE024*/ locationsystem SET strvar =  REPLACE(strvar, SUBSTRING_INDEX(strvar,'|',1) ,DATE_FORMAT( DATE_ADD(NOW(), INTERVAL $int_AUBIL HOUR),'%Y-%m-%d %H:%i:%s') ) WHERE recid = '38AUB' AND locationid = '$clientLocId'";
				print "$sql\n" if ($debug);
				$dbh->do($sql) or die "$sql;\n"; 
				
		#Task#8532 End		
				
		#ClientSystem = SE024 cases, when the processing is complete for a client,
					# send an email to those listed in NotifyGroup "INV".
					# (Persons related by NotifyPerson.PersonLinkId where GroupCode = "INV")
					my @emailList;
					$sql = "SELECT /*SE024*/ p.email FROM personlink pl, person p, notifyperson np, notifygrouplink ngl WHERE ngl.groupcode = 'AUB' AND ngl.locationid = '$clientLocId' AND ngl.groupcode = np.groupcode AND np.personlinkid = pl.recid AND pl.locationid = ngl.locationid AND pl.personid = p.recid";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					while (my ($emailId) = $sth->fetchrow_array()) {
						push @emailList, $emailId;
					}
					$sth->finish();

					# Actually sending emails for notification.

					
					$sql = "SELECT /*SE024*/ DATE_FORMAT(DATE_ADD(ls1.strvar, INTERVAL ls2.intvar HOUR), '%m-%d-%y %r'),DATE_FORMAT(DATE_ADD(ls1.datevar, INTERVAL ls2.intvar HOUR), '%m-%d-%y') FROM locationsystem ls1, locationsystem ls2 WHERE ls2.recid = 'TIMEO' AND ls1.recid = 'AUBIL' AND ls2.locationid =  '$clientLocId' AND ls1.locationid = ls2.locationid ";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my ($formatedTime , $formatedDate) = $sth->fetchrow_array();
					$sth->finish();

					my $message = "";
					
					$message = "Customer invoices have been created with an invoice date $formatedDate. \nPlease review them going to Data>>>Billing and Receiving, invoices will be automatically processed at $formatedTime\n";
						
					my $subject = "Customer Invoices created for $formatedDate";
					my $from = 'noreply@teakwce.com';

					foreach my $emailTo (@emailList) {
						my $email = MIME::Entity->build(From => "$from",
														  To       => "$emailTo",
														  Subject  => "$subject",
														  Data	   => "$message");
						eval{
							$email->smtpsend;
							print "Mail sent to $emailTo From $from\n";
						};
						if($@){
							print "Could Not Able to send email to $emailTo\n" if ($debug);
			 			}
					}
		
	}
	#Task#8460 End
	return $AUBIL_Flag; #Task#8840
}

sub processVendors {
	my ($clientId, $clientLocId) = @_;
	my $Email_Inv = 0; #Task#8840
	#/* Task#8394 Starts*/
	$sql = "SELECT /*se024*/ charvar FROM locationsystem WHERE locationid = '$clientLocId' AND recid = 'SUMTA' AND (endeffdt = '0000-00-00' OR endeffdt IS NULL OR endeffdt > now())";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my ($char_SUMTA) = $sth->fetchrow_array();
	$sth->finish();
	#/* Task#8394 Ends*/

	$sql = "SELECT DISTINCT(l.recid) FROM location l, locationlink ll, vendorlink vl WHERE vl.clientid = '$clientId' AND vl.locationid = ll.locationid AND l.recid = ll.locationid AND l.effdate < '". $runDate->getDate() ."' AND (l.endeffdate IS NULL OR l.endeffdate = '0000-00-00' OR l.endeffdate > '". $runDate->getDate() ."')";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $refVendorLocIds = $sth->fetchall_arrayref();
	$sth->finish();

	#SE035 logic-----start
	my $Se035Flg = 0;
	my $Se035ClientId = '';
	my $Se035RunDate = '';
	#SE035 logic-----End
	
	$sql = "SELECT charvar FROM clientsystem WHERE recid = 'COLAG' AND clientid = '$clientId' AND (endeffdt = '0000-00-00' OR endeffdt IS NULL OR endeffdt > NOW())";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my ($charvar_COLAG) = $sth->fetchrow_array();
			$sth->finish();
	
	
	
	my @vendorLocIds = @$refVendorLocIds;
	foreach my $record (@vendorLocIds) {

		my $vendorLocId = $record->[0];
		print "$vendorLocId\n" if ($debug);

		if (length($vendorLocId) == 0) {
			$vendorLocId = 0;
		}

		# CHECKING THE VALID PUBLILCATIONS FOR THE SELECTED LOCATIONS IN THE PRODUCT TABLE
		$sql = "SELECT recid, sdesc, payablesdaycodeid, billingperioddaycodeid, basepayablesdate, basepayablesperioddate, returnsbasis, returnsexception, returnsfactor  FROM product WHERE clientid = '$clientId' and vendorlocid = '$vendorLocId' /*AND producttype = 'PU'*/";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my $refProuctIds = $sth->fetchall_arrayref();
		$sth->finish();

		my @products = @$refProuctIds;
		foreach my $record1 (@products) {

			my $productId = $record1->[0];
			my $prodDesc = $record1->[1];
			my $payablesDaycodeId = $record1->[2];
			my $billingDaycodeId = $record1->[3];
			my $payablesBaseDate = $record1->[4];
			my $payablesPeriodDate = $record1->[5];
			my $returnsBasis = $record1->[6];
			my $returnsException = $record1->[7];
			my $returnsFactor = $record1->[8];

			if (length($productId) == 0 || length($payablesDaycodeId) == 0 || length($billingDaycodeId) == 0) {
				$productId = 0;
				$payablesDaycodeId = 0;
				$billingDaycodeId = 0;
			}

			if ($productId == 0 || $payablesDaycodeId == 0 || $billingDaycodeId == 0) {
				next ;
			}

			# GETTING THE DAYCODE VALUES FOR PAYABLESDAYCODEID

			my $isPayablesDay = isLocationOpen($runDate->getDate(), $payablesDaycodeId, $payablesBaseDate, $billingDaycodeId, $payablesPeriodDate);

			if ($isPayablesDay == 0) {
				next ;
			}

			$sql = "SELECT type, period, sequence FROM daycode WHERE recid = '$payablesDaycodeId'";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my ($type, $period, $sequence) = $sth->fetchrow_array();
			$sth->finish();

			# WHEN TYPE IS "L" THEN CHANGE THE RUNDATE BACK TO THE RELATIVE DAYS FOR THE BILLINGDAYCODEID
			my $tempRunDate = '';
			if($type eq "L"){
				$tempRunDate = $runDate->getDate();
				# Finding the lagging period
				my $lag = $sequence * 7;
				$runDate->setDate($runDate->addDaysToDate($lag * -1));

			} # end of lagging period condition.



			my $endingDate;
			if($val_MANAR > 0) {
				$sql = "SELECT periodenddate FROM ".$archObj->archDB.".productpayables WHERE clientlocid = '$clientLocId' AND vendorlocid = '$vendorLocId' AND type = 'I' AND source = 'T' ORDER BY periodenddate DESC LIMIT 1";
				$sth = $dbh->prepare($sql);
				$sth->execute() || die "$sql;\n";
				my ($latestPDEndDate) = $sth->fetchrow_array();
				$sth->finish();

				if(length($latestPDEndDate) == 0) {
					$endingDate = getEndingDate($period, $runDate->getDate(), $billingDaycodeId, $payablesPeriodDate);
				} else {
					$latestPDEndDate = cvt_general::DateOperation($latestPDEndDate, 1, "ADD");
					my $nextPDEndDate = getFutureEndDateFromStartDate($latestPDEndDate, $billingDaycodeId, $payablesPeriodDate);
					if($nextPDEndDate ge $runDate->getDate()) {
						$latestPDEndDate = cvt_general::DateOperation($latestPDEndDate, 1, "SUB");
						$endingDate = $latestPDEndDate;
					} else {
						$endingDate = $nextPDEndDate;
					}
				}
			} else {
				$endingDate = getEndingDate($period, $runDate->getDate(), $billingDaycodeId, $payablesPeriodDate);
				print "isPayablesDay:$isPayablesDay\nendingDate:$endingDate\n" if($debug);
				if ($isPayablesDay =~ /-/) {
					$endingDate = $isPayablesDay;
				}
			}

			print "ending_date:$endingDate\n" if ($debug);
			if (length($tempRunDate) > 0) {
				$runDate->setDate($tempRunDate);
				$tempRunDate = '';
			}

			if (length($endingDate) == 0) {
				#Billing date not found move to next product
				next ;
			}

			# Check for the existance of ARLAG variable for this client.
			$sql = "SELECT strvar FROM locationsystem WHERE recid = 'ARLAG' AND locationid = '$clientLocId' AND (endeffdt = '0000-00-00' OR endeffdt IS NULL OR endeffdt > NOW())";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my ($strvar_ARLAG) = $sth->fetchrow_array();
			$sth->finish();

			my $prodLag = 0;
			if ($strvar_ARLAG =~ /$prodDesc~/) {
				# ARLAG record found.
				my @prodStr = split(/\|/, $strvar_ARLAG);
				print "prodStr" . "@prodStr" , "\n" if ($debug);

				foreach my $rec (@prodStr) {
					my ($key, $value) = split(/~/, $rec);
					if ($key eq $prodDesc) {
						$prodLag = $value;
					}
				}
			}

			if ($returnsBasis eq "C" && $returnsException eq "N") {
				my $starting_date = getStartingDate($period, $endingDate, $billingDaycodeId, $payablesPeriodDate);
				if ($starting_date < $endingDate) {
					$sql = "SELECT datevar FROM system WHERE recid = 'WOFDT'";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my $val_WODFT = ($sth->fetchrow_array())[0];
					$sth->finish();

					$sql = $archObj->processSQL("UPDATE transactivity, specificproduct SET transactivity.closeddatevend = '$val_WODFT', transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.locationid = '$clientLocId' AND transactivity.specificproductid = specificproduct.recid AND specificproduct.productid = '$productId' AND specificproduct.datex < '$starting_date' AND (transactivity.closeddatevend IS NULL OR transactivity.closeddatevend = '0000-00-00') AND transactivity.type IN ('DE', 'PU', 'AD')");
					print "$sql\n" if ($debug);
					$dbh->do($sql) or die "$sql;\n";
				}
			}


			#If the related Product.ReturnsException = "D", find the related Product.ReturnsFactor and, if the SpecificProduct.DateX of the TransActivity record being processed is < today minus Product.ReturnsFactor, set all of the ClosedDateXXX values to INDEF
			if ($returnsException eq "D" && length($returnsFactor) > 0 && $returnsFactor > 0) {
				my $exceptionDt = $runDate->addDaysToDate($returnsFactor * -1);
				$sql = $archObj->processSQL("UPDATE transactivity, specificproduct, product  SET transactivity.closeddatevend = '$val_INDEF', transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.locationid = '$clientLocId' AND transactivity.specificproductid = specificproduct.recid AND specificproduct.productid = product.recid AND product.recid = '$productId' AND specificproduct.datex < '$exceptionDt' AND (transactivity.closeddatevend IS NULL OR transactivity.closeddatevend = '0000-00-00') AND transactivity.type IN ('DE', 'PU', 'AD')");
				print "$sql\n" if ($debug);
				$dbh->do($sql) or die "$sql;\n";
			}



			#CALCULATION OF EACH PUBLICATION FOR WHICH IS OPEN FOR PAYABLES.
			my $deAmount = 0;
			my $puAmount = 0;
			my $totalAmount = 0;

			my $customerList = "";
			$sql = "SELECT DISTINCT(sd.customerlocid) FROM standarddraw sd WHERE sd.effdt <= '$endingDate' AND clientlocid = '$clientLocId' AND productid = '$productId'  AND (sd.endeffdt IS NULL OR sd.endeffdt = '0000-00-00' OR sd.endeffdt < '$endingDate') ORDER BY sd.effdt DESC";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my $refTempCustomerList = $sth->fetchall_arrayref();
			$sth->finish();

			my @tempCustomerList = @{$refTempCustomerList};

			foreach my $rec (@tempCustomerList) {
				$sql = "SELECT costcodeid FROM standarddraw WHERE customerlocid = '$rec->[0]' AND effdt <= '$endingDate' AND clientlocid = '$clientLocId' AND productid = '$productId'  AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt < '$endingDate') ORDER BY effdt DESC LIMIT 1";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my $costCodeId = ($sth->fetchrow_array())[0];
				$sth->finish();

				if (length($costCodeId) == 0 || $costCodeId == 0) {
					$customerList .= $rec->[0] . ",";
				}
			}

			$customerList =~ s/,$//;
			if (length($customerList) == 0) {
				$customerList = 0;
			}

			$sql = $archObj->processSQL("UPDATE transactivity, specificproduct SET transactivity.closeddatevend = '$val_INDEF', transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND (transactivity.closeddatevend IS NULL OR transactivity.closeddatevend = '0000-00-00') AND transactivity.type IN ('DE', 'PU', 'AD') AND transactivity.specificproductid = specificproduct.recid AND specificproduct.productid = '$productId' AND transactivity.locationid = '$clientLocId' AND transactivity.customerlocid IN ($customerList) AND specificproduct.datex <= '$endingDate'");
			print "$sql\n" if ($debug);
			$dbh->do($sql) or die "$sql;\n";


			my $isExists = 0;
			if ($prodLag eq "N") {
			} elsif ($prodLag eq "R") {
			} else {
				$sql = $archObj->processSQL("SELECT COUNT(*) FROM transactivity ta, specificproduct sp WHERE ta.recid <= '$maxTaRecId' AND ta.type IN ('DE', 'PU' , 'AD') AND (ta.closeddatevend IS NULL OR ta.closeddatevend = '0000-00-00') AND ta.locationid = '$clientLocId' AND sp.recid = ta.specificproductid AND sp.datex <= DATE_SUB('$endingDate', INTERVAL $prodLag DAY) AND sp.productid = '$productId'");
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				$isExists = ($sth->fetchrow_array())[0];
				$sth->finish();
			}

			if ($isExists > 0 || $prodLag eq "R" || $prodLag eq "N") {

#				$sql = "SELECT recid, billingflag FROM productpayables WHERE clientlocid = '$clientLocId' AND vendorlocid = '$vendorLocId' AND payabledate = '". $runDate->getDate() ."' AND periodenddate = '$endingDate' AND type = 'I' AND source = 'T' AND publicationid = '$productId'";
				$sql = "SELECT recid, billingflag, payabledate FROM productpayables WHERE clientlocid = '$clientLocId' AND vendorlocid = '$vendorLocId' AND periodenddate = '$endingDate' AND type = 'I' AND source = 'T' AND publicationid = '$productId'";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my ($productPayRecId, $productPayableBillingFlag, $invDate) = $sth->fetchrow_array();
				$sth->finish();

				if (($productPayableBillingFlag eq "Y" || $productPayableBillingFlag eq "P") && length($productPayRecId) > 0 && $productPayRecId > 0) {
					next;
				}

				my $rowsUpdated = 0;
				my $RecProcFlag = 0;
				if ($prodLag eq "N") {
					my $startDate = getStartingDate($period, $endingDate, $billingDaycodeId, $payablesPeriodDate);
					$sql = "SELECT recid FROM specificproduct WHERE productid = '$productId' AND datex >= '$startDate' AND datex <= '$endingDate'";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my ($spProdId) = $sth->fetchrow_array();
					$sth->finish();

					$sql = $archObj->processSQL("SELECT COUNT(*) FROM transactivity WHERE recid <= '$maxTaRecId' AND locationid = '$clientLocId' AND type = 'SD' AND (closeddatevend IS NULL OR closeddatevend = '0000-00-00' OR closeddatevend = '$invDate') AND specificproductid = '$spProdId'");
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my ($isSDExists) = $sth->fetchrow_array();
					$sth->finish();

					if ($isSDExists) {
						$sql = "SELECT sp1.recid FROM specificproduct sp, specificproduct sp1 WHERE sp.recid = '$spProdId' AND sp.productid = sp1.productid AND sp1.datex < sp.datex ORDER BY sp1.datex DESC LIMIT 1";
						print "$sql\n" if ($debug);
						$sth = $dbh->prepare($sql);
						$sth->execute() or die "$sql;\n";
						my ($prevSPId) = $sth->fetchrow_array();

						if (length($productPayRecId) > 0 && $productPayRecId > 0) {
							$sql = $archObj->processSQL("UPDATE transactivity SET closeddatevend = '". $runDate->getDate() ."', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid <= '$maxTaRecId' AND locationid = '$clientLocId' AND type IN ('DE', 'PU' , 'AD') AND (closeddatevend IS NULL OR closeddatevend = '0000-00-00' OR closeddatevend = '$invDate') AND specificproductid = '$prevSPId'");
						} else {
							$sql = $archObj->processSQL("UPDATE transactivity SET closeddatevend = '". $runDate->getDate() ."', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid <= '$maxTaRecId' AND locationid = '$clientLocId' AND type IN ('DE', 'PU' , 'AD') AND (closeddatevend IS NULL OR closeddatevend = '0000-00-00') AND specificproductid = '$prevSPId'");
						}
						print "$sql\n" if ($debug);
						$rowsUpdated = $dbh->do($sql) or die "$sql;\n";
						
						#SE035 logic-----Start
						
						$Se035Flg++;
						$Se035ClientId = $clientId;
						$Se035RunDate = $runDate->getDate();
						
						#SE035 logic-----End
					}
				} elsif ($prodLag eq "R") {
					my $startDate = getStartingDate($period, $endingDate, $billingDaycodeId, $payablesPeriodDate);

					my $spProdIds;
					$sql = $archObj->processSQL("SELECT DISTINCT ta.specificproductid FROM transactivity ta, specificproduct sp WHERE ta.recid <= '$maxTaRecId' AND ta.locationid = '$clientLocId' AND ta.type = 'SP' AND ta.datet >= '$startDate' AND ta.datet <= '$endingDate' AND ta.specificproductid = sp.recid AND sp.productid = '$productId' AND (sp.endeffdt IS NULL OR sp.endeffdt = '0000-00-00' OR sp.endeffdt > NOW())");
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					while (my ($val) = $sth->fetchrow_array()) {
						$spProdIds .= length($spProdIds) == 0 ? $val : "," . $val;
					}
					$sth->finish();

					if (length($spProdIds) > 0) {
						if (length($productPayRecId) > 0 && $productPayRecId > 0) {
							$sql = $archObj->processSQL("UPDATE transactivity SET closeddatevend = '". $runDate->getDate() ."', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid <= '$maxTaRecId' AND locationid = '$clientLocId' AND type IN ('DE', 'PU' , 'AD') AND (closeddatevend IS NULL OR closeddatevend = '0000-00-00' OR closeddatevend = '$invDate') AND specificproductid IN ($spProdIds)");
						} else {
							$sql = $archObj->processSQL("UPDATE transactivity SET closeddatevend = '". $runDate->getDate() ."', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid <= '$maxTaRecId' AND locationid = '$clientLocId' AND type IN ('DE', 'PU' , 'AD') AND (closeddatevend IS NULL OR closeddatevend = '0000-00-00') AND specificproductid IN ($spProdIds)");
						}
						print "$sql\n" if ($debug);
						$rowsUpdated = $dbh->do($sql) or die "$sql;\n";
						
						#SE035 logic-----Start
						
						$Se035Flg++;
						$Se035ClientId = $clientId;
						$Se035RunDate = $runDate->getDate();
						
						#SE035 logic-----End
					}

				} else {
				
				
				if($charvar_COLAG eq 'Y')
				{
					
					print "\n \n Process 'J' and 'K' as charvar_COLAG: $charvar_COLAG set \n \n \n ";
					#Changes related to skedretn J and K implementation started			
					$sql = "SELECT DISTINCT(sd.customerlocid) FROM standarddraw sd WHERE sd.effdt <= '$endingDate' AND clientlocid = '$clientLocId' AND productid = '$productId'  AND (sd.endeffdt IS NULL OR sd.endeffdt = '0000-00-00' OR sd.endeffdt < '$endingDate') ORDER BY sd.effdt DESC";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my $refTempCustomerList = $sth->fetchall_arrayref();
					$sth->finish();

					my @tempCustomerList = @{$refTempCustomerList};

					foreach my $rec (@tempCustomerList) {
					
					
							
			
						my $fullProdListNew;
						my $fullProdList;
						my $lagWhereStrx;
						
										
						my $customerLocId = $rec->[0];						
							my $isJExists;
							my $isKExists;
							my $isNExists;
							my $startDate = getStartingDate($period, $endingDate, $billingDaycodeId, $payablesPeriodDate);
							
							
							$sql = "SELECT recid, productid, skedretn  FROM standarddraw WHERE productid = '$productId' AND customerlocid = '$customerLocId' AND clientlocid = '$clientLocId' AND effdt <= '$endingDate' /*AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > '$startDate')*/ ORDER BY effdt DESC LIMIT 1";
							print "$sql\n" if ($debug);
							$sth = $dbh->prepare($sql);
							$sth->execute() or die "$sql;\n";
							my ($stdRecIdChk , $prodIdChk, $skedRetn) = $sth->fetchrow_array();
							my $stdRows = $dbh->do($sql) or die "$sql;\n";
							$sth->finish();
							
						
							
							if($skedRetn eq 'J')
							{
							$sql = "SELECT COUNT(*) FROM specificproduct WHERE productid = '$productId' AND datex >= '$startDate' AND datex <= '$endingDate' ";
								print "$sql\n;" if($debug);
								$sth = $dbh->prepare($sql);
								$sth->execute() or die "$sql;\n";
								$isJExists = $sth->fetchrow_array();
								$sth->finish();
							}
							elsif($skedRetn eq 'K')
							{
							$sql = "SELECT COUNT(*) FROM specificproduct WHERE productid = '$productId' AND skedretndate >= '$startDate' AND skedretndate <= '$endingDate' ";
								print "$sql\n;" if($debug);
								$sth = $dbh->prepare($sql);
								$sth->execute() or die "$sql;\n";
								$isKExists = $sth->fetchrow_array();
								$sth->finish();
							}
							else
							{
							$sql = "SELECT COUNT(*) FROM specificproduct WHERE productid = '$productId' /*AND datex >= '$startDate'*/ AND datex <= '$endingDate' ";
								print "$sql\n;" if($debug);
								$sth = $dbh->prepare($sql);
								$sth->execute() or die "$sql;\n";
								$isNExists = $sth->fetchrow_array();
								$sth->finish();
							}
			
							
							if ($stdRows > 0 && length($prodIdChk) > 0) {
								if($skedRetn eq 'J' && $isJExists > 0) {
									$lagWhereStrx .= " OR (specificproduct.productid = '".$prodIdChk."' AND specificproduct.datex < '".$startDate."' AND (specificproduct.endeffdt IS NULL OR specificproduct.endeffdt = '0000-00-00'))";
								}
								elsif($skedRetn eq 'K' && $isKExists > 0) {
									$lagWhereStrx .= " OR (specificproduct.productid = '".$prodIdChk."' AND specificproduct.skedretndate <= '".$endingDate."' AND specificproduct.skedretndate >= '".$startDate."' AND (specificproduct.endeffdt IS NULL OR specificproduct.endeffdt = '0000-00-00'))";
								}
								elsif($isNExists > 0) {
									$fullProdListNew .= length($fullProdListNew) == 0 ? $prodIdChk : "," . $prodIdChk;
								}
							}
						
						
						if(length($fullProdListNew) > 0) {
							$fullProdList = $fullProdListNew;
						}
						
						print "fullProdList:$fullProdList\n" if ($debug);
						

						$fullProdList =~ s/,$|^,//g;
						$fullProdList =~ s/,,/,/g;
						print "fullProdList:$fullProdList\n" if ($debug);

						if (length($fullProdList) == 0) {
							# If all products are of LAG type then, modifiy the LAG where condition to properly build the query
							if (length($lagWhereStrx) > 0) {
								$lagWhereStrx = substr($lagWhereStrx, 4);
							}
						} else {
							# Both product exists so again add the excluded product list and lag product list to build the query
							$lagWhereStrx = "(specificproduct.productid IN ($fullProdList) AND specificproduct.datex <= '$endingDate')" . $lagWhereStrx;
						}

						print "lagWhereStr:$lagWhereStrx\n" if ($debug);
						
						
		#Changes related to skedretn J and K implementation end - more changes in update queries				
						
						
						if($lagWhereStrx)
						{
						
							my $qry1= '';
							if (length($productPayRecId) > 0 && $productPayRecId > 0) {
								#$qry1= "UPDATE transactivity, specificproduct SET transactivity.closeddatevend = '". $runDate->getDate() ."', transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.locationid = '$clientLocId' AND transactivity.type IN ('DE', 'PU' , 'AD') AND (transactivity.closeddatevend IS NULL OR transactivity.closeddatevend = '0000-00-00' OR transactivity.closeddatevend = '$invDate') AND specificproduct.recid = transactivity.specificproductid AND specificproduct.datex <= DATE_SUB('$endingDate', INTERVAL $prodLag DAY) AND specificproduct.productid = '$productId'";
								
								 $qry1 = "UPDATE transactivity, specificproduct SET transactivity.closeddatevend = '". $runDate->getDate() ."',  transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.type IN ('DE', 'PU', 'AD') AND (transactivity.closeddatevend IS NULL OR transactivity.closeddatevend = '0000-00-00' OR transactivity.closeddatevend = '$invDate') AND transactivity.specificproductid = specificproduct.recid AND transactivity.customerlocid = '$customerLocId' AND transactivity.locationid = '$clientLocId' ";
								
							
											
							} else {
								#$qry1 = "UPDATE transactivity, specificproduct SET transactivity.closeddatevend = '". $runDate->getDate() ."', transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.locationid = '$clientLocId' AND transactivity.type IN ('DE', 'PU' , 'AD') AND (transactivity.closeddatevend IS NULL OR transactivity.closeddatevend = '0000-00-00') AND specificproduct.recid = transactivity.specificproductid AND specificproduct.datex <= DATE_SUB('$endingDate', INTERVAL $prodLag DAY) AND specificproduct.productid = '$productId'";
								
								 $qry1 = "UPDATE transactivity, specificproduct SET transactivity.closeddatevend = '". $runDate->getDate() ."',  transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.type IN ('DE', 'PU', 'AD') AND (transactivity.closeddatevend IS NULL OR transactivity.closeddatevend = '0000-00-00') AND transactivity.specificproductid = specificproduct.recid  AND transactivity.customerlocid = '$customerLocId' AND transactivity.locationid = '$clientLocId' ";
							
							}
							if(length($lagWhereStrx) > 0) {
								$qry1  .= " AND ($lagWhereStrx) ";
							}
							
							print "\n\n qry1:$qry1 \n \n \n ";
							$sql = $archObj->processSQL("$qry1");
							print "$sql\n" if ($debug);
							$rowsUpdated = $dbh->do($sql) or die "$sql;\n";
							if($rowsUpdated){
								$RecProcFlag = 1;
							}
							
						}	
							
					}	
				}else{
				
					if (length($productPayRecId) > 0 && $productPayRecId > 0) {
						$sql = $archObj->processSQL("UPDATE transactivity, specificproduct SET transactivity.closeddatevend = '". $runDate->getDate() ."', transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.locationid = '$clientLocId' AND transactivity.type IN ('DE', 'PU' , 'AD') AND (transactivity.closeddatevend IS NULL OR transactivity.closeddatevend = '0000-00-00' OR transactivity.closeddatevend = '$invDate') AND specificproduct.recid = transactivity.specificproductid AND specificproduct.datex <= DATE_SUB('$endingDate', INTERVAL $prodLag DAY) AND specificproduct.productid = '$productId'");
					} else {
						$sql = $archObj->processSQL("UPDATE transactivity, specificproduct SET transactivity.closeddatevend = '". $runDate->getDate() ."', transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.locationid = '$clientLocId' AND transactivity.type IN ('DE', 'PU' , 'AD') AND (transactivity.closeddatevend IS NULL OR transactivity.closeddatevend = '0000-00-00') AND specificproduct.recid = transactivity.specificproductid AND specificproduct.datex <= DATE_SUB('$endingDate', INTERVAL $prodLag DAY) AND specificproduct.productid = '$productId'");
					}
					print "$sql\n" if ($debug);
					$rowsUpdated = $dbh->do($sql) or die "$sql;\n";
					
					if($rowsUpdated){
								$RecProcFlag = 1;
							}
					#SE035 logic-----Start
						
						
				
				
				}	
					#SE035 logic-----Start
						
						$Se035Flg++;
						$Se035ClientId = $clientId;
						$Se035RunDate = $runDate->getDate();
						
						#SE035 logic-----End
				}

				if ($RecProcFlag > 0) {

					# Calculate the DE Amount
					$sql = $archObj->processSQL("SELECT SUM(ta.actquantity * ta.unitcost) as desum FROM transactivity ta, specificproduct sp WHERE ta.recid <= '$maxTaRecId' AND sp.productid = '$productId' AND ta.specificproductid = sp.recid AND ta.locationid = '$clientLocId' AND ta.closeddatevend = '". $runDate->getDate() ."' AND (ta.type = 'DE' OR ta.type = 'AD')");
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					$deAmount = ($sth->fetchrow_array())[0];
					$sth->finish();

					$deAmount = sprintf("$format",$deAmount);

					# Calculate the PU Amount
					$sql = $archObj->processSQL("SELECT SUM(ta.actquantity * ta.unitcost) as pusum FROM transactivity ta, specificproduct sp WHERE ta.recid <= '$maxTaRecId' AND ta.locationid = '$clientLocId' AND sp.productid = '$productId' AND ta.specificproductid = sp.recid AND ta.closeddatevend = '". $runDate->getDate() ."' AND ta.type = 'PU'");
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					$puAmount = ($sth->fetchrow_array())[0];
					$sth->finish();

					$puAmount = sprintf("$format",$puAmount);

					$totalAmount = $deAmount - $puAmount;
					$totalAmount = sprintf("$format",$totalAmount);
					$totalAmount = $totalAmount * -1;

					if (length($productPayRecId) > 0 && $productPayRecId > 0) {
						$sql = "UPDATE productpayables SET totalamount = '$totalAmount', drawamount = '$deAmount', returnamount = '$puAmount', payabledate = '". $runDate->getDate() ."', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid = '$productPayRecId'";
						print "$sql\n" if ($debug);
						$dbh->do($sql) or die "$sql;\n";
					} else {
					# NOW INSERT A RECORD INTO THE PRODUCTPAYABLES FOR PAYING
						$sql = "INSERT INTO productpayables(clientlocid, vendorlocid, publicationid, type, payabledate, periodenddate, totalamount, billingflag, source, drawamount, returnamount) values('$clientLocId', '$vendorLocId', '$productId', 'I', '". $runDate->getDate() ."', '$endingDate', '$totalAmount', 'N', 'T', '$deAmount', '$puAmount')";
						print "$sql\n" if ($debug);
						$dbh->do($sql) or die "$sql;\n";
						$Email_Inv = 1; #Task#8840
						#/* Task#8394 Starts*/
						my $productpayablesId = $dbh->{'mysql_insertid'};
						if($char_SUMTA eq 'Y') {
							cvt_general::insertInvoiceTaLinkProductInvoice($dbh, $clientId, $clientLocId, $vendorLocId, $productId, 'C', 'I', $endingDate, $runDate->getDate(), $productpayablesId, 'SE024');
						}
						#/* Task#8394 Ends*/
					}

					$invoicedPDEndDate .= length($invoicedPDEndDate) == 0 ? $endingDate : "," . $endingDate;

				}
			} # END OF UPDATIONG THE TRANSACTIVITY RECORDS
		} # END OF PUBLICATION WHILE LOOP
	} # END OF LOCATIONWISE PUBLICATION
	
		print "\nFlg => $Se035Flg\nClientId => $Se035ClientId\n RunDate => $Se035RunDate\n";
		if($Se035Flg > 0){
	
		
		$sql = "SELECT clientid FROM clientsystem WHERE recid = 'SE035' AND clientid = '$Se035ClientId'";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my $isClientRunTimeExists = $sth->rows();
		$sth->finish();
		if($isClientRunTimeExists)
		{
		
		$sql = "UPDATE clientsystem SET datevar = '". $Se035RunDate ."' WHERE recid = 'SE035' AND clientid = '$Se035ClientId'";
		print "$sql\n" if ($debug);
		$dbh->do($sql) or die "$sql;\n";
		
		}
		else{
	
			print "\n\n\n\n\nFlg => $Se035Flg\nClientId => $Se035ClientId\nRunDate => $Se035RunDate\n";
			print "\n\n\n\nclientSystem Record dosen't exist\n";
			
		}	
	}
return $Email_Inv; #Task#8840
}


sub processDeliveryFee {
	my ($clientId, $clientLocId) = @_;
	
	#/* Task#8394 Starts*/
	$sql = "SELECT /*se024*/ charvar FROM locationsystem WHERE locationid = '$clientLocId' AND recid = 'SUMTA' AND (endeffdt = '0000-00-00' OR endeffdt IS NULL OR endeffdt > now())";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my ($char_SUMTA) = $sth->fetchrow_array();
	$sth->finish();
	#/* Task#8394 Ends*/

	$sql = "SELECT p.recid, p.sdesc, p.feedaycodeid, p.basefeedate, p.feeperioddaycodeid, p.basefeeperioddate, p.vendorlocid, p.returnsexception,  p.returnsfactor FROM product p WHERE p.clientid = '$clientId' /*AND p.producttype = 'PU'*/ AND (p.vendorlocid IS NOT NULL AND p.vendorlocid > 0) AND (p.feedaycodeid IS NOT NULL AND p.feedaycodeid > 0) AND (p.feeperioddaycodeid IS NOT NULL AND p.feeperioddaycodeid > 0)";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $refVendorLocs = $sth->fetchall_arrayref();
	$sth->finish();

	my @vendorLocs = @$refVendorLocs;

	my $runDateDOW = $runDate->getDayOfWeek(); #cvt_general::DayOfWeek($runDate);
	my $monthEndDate = $runDate->getMonthEndDate();

	foreach my $record (@vendorLocs) {
		my ($productId, $prodDesc, $feeDaycodeId, $feeBaseDate, $feePeriodDaycodeId, $feePeriodBaseDate, $vendorLocId, $returnsException, $returnsFactor) = @{$record};

		my $isLocationOpen = isLocationOpen($runDate->getDate(), $feeDaycodeId, $feeBaseDate, $feePeriodDaycodeId, $feePeriodBaseDate);

		if ($isLocationOpen == 0) {
			next ;
		}

		$sql = "SELECT type, period, sequence FROM daycode WHERE recid = $feeDaycodeId";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my ($type, $period, $sequence) = $sth->fetchrow_array();
		$sth->finish();

		# WHEN TYPE IS "L" THEN CHANGE THE RUNDATE BACK TO THE RELATIVE DAYS FOR THE BILLINGDAYCODEID
		my $tempRunDate = '';
		if($type eq "L"){
			$tempRunDate = $runDate->getDate();
			# Finding the lagging period
			my $lag = $sequence * 7;
			$runDate->setDate($runDate->addDaysToDate($lag * -1));

		} # end of lagging period condition.


		my $endingDate;
		if($val_MANAR > 0) {
			$sql = "SELECT periodenddate FROM ".$archObj->archDB.".productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$vendorLocId' AND type = 'I' AND source = 'F' ORDER BY periodenddate DESC LIMIT 1";
			$sth = $dbh->prepare($sql);
			$sth->execute() || die "$sql;\n";
			my ($latestPDEndDate) = $sth->fetchrow_array();
			$sth->finish();

			if(length($latestPDEndDate) == 0) {
				$endingDate = getEndingDate($period, $runDate->getDate(), $feePeriodDaycodeId, $feePeriodBaseDate);
			} else {
				$latestPDEndDate = cvt_general::DateOperation($latestPDEndDate, 1, "ADD");
				my $nextPDEndDate = getFutureEndDateFromStartDate($latestPDEndDate, $feePeriodDaycodeId, $feePeriodBaseDate);
				if($nextPDEndDate ge $runDate->getDate()) {
					$latestPDEndDate = cvt_general::DateOperation($latestPDEndDate, 1, "SUB");
					$endingDate = $latestPDEndDate;
				} else {
					$endingDate = $nextPDEndDate;
				}
			}
		} else {
			$endingDate = getEndingDate($period, $runDate->getDate(), $feePeriodDaycodeId, $feePeriodBaseDate);
			print "isLocationOpen:$isLocationOpen\nendingDate:$endingDate\n" if($debug);
			if ($isLocationOpen =~ /-/) {
				$endingDate = $isLocationOpen;
			}
		}

		print "ending_date:$endingDate\n" if ($debug);

		if (length($tempRunDate) > 0) {
			$runDate->setDate($tempRunDate);
			$tempRunDate = '';
		}

		if (length($endingDate) > 0) {

			# If the related Product.ReturnsException = "D", find the related Product.ReturnsFactor and, if the SpecificProduct.DateX of the TransActivity record being processed is < today minus Product.ReturnsFactor, set all of the ClosedDateXXX values to INDEF
			if ($returnsException eq "D" && length($returnsFactor) > 0 && $returnsFactor > 0) {
				my $exceptionDt = $runDate->addDaysToDate($returnsFactor * -1);
				$sql = $archObj->processSQL("UPDATE transactivity, specificproduct, product SET transactivity.closeddatevendinv = '$val_INDEF', transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND (transactivity.closeddatevendinv IS NULL OR transactivity.closeddatevendinv = '0000-00-00') AND transactivity.type IN ('DE', 'PU', 'AD') AND transactivity.specificproductid = specificproduct.recid AND specificproduct.productid = product.recid AND product.recid = '$productId' AND transactivity.locationid = '$clientLocId'  AND specificproduct.datex < '$exceptionDt'");
				print "$sql\n" if ($debug);
				$dbh->do($sql) or die "$sql;\n";
			}

			# Check for the existance of ARLAG variable for this client.
			$sql = "SELECT strvar FROM locationsystem WHERE recid = 'ARLAG' AND locationid = '$clientLocId' AND (endeffdt = '0000-00-00' OR endeffdt IS NULL OR endeffdt > NOW())";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my ($strvar_ARLAG) = $sth->fetchrow_array();
			$sth->finish();

			my $prodLag = 0;
			if ($strvar_ARLAG =~ /$prodDesc~/) {
				# ARLAG record found.
				my @prodStr = split(/\|/, $strvar_ARLAG);
				print "prodStr" . "@prodStr" , "\n" if ($debug);

				foreach my $rec (@prodStr) {
					my ($key, $value) = split(/~/, $rec);
					if ($key eq $prodDesc) {
						$prodLag = $value;
					}
				}
			}

			my $customerList = "";
			$sql = "SELECT DISTINCT(sd.customerlocid) FROM standarddraw sd WHERE sd.effdt <= '$endingDate' AND clientlocid = '$clientLocId' AND productid = '$productId'  AND (sd.endeffdt IS NULL OR sd.endeffdt = '0000-00-00' OR sd.endeffdt < '$endingDate') ORDER BY sd.effdt DESC";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my $refTempCustomerList = $sth->fetchall_arrayref();
			$sth->finish();

			my @tempCustomerList = @{$refTempCustomerList};
			foreach my $rec (@tempCustomerList) {
				$sql = "SELECT pricecodevendid  FROM standarddraw WHERE customerlocid = '$rec->[0]'  AND effdt <= '$endingDate' AND clientlocid = '$clientLocId' AND productid = '$productId'  AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt < '$endingDate') ORDER BY effdt DESC LIMIT 1";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my $pcvid = ($sth->fetchrow_array())[0];
				$sth->finish();
				if (length($pcvid) == 0 || $pcvid == 0) {
					$customerList .= $rec->[0] . ",";
				}
			}
			$sth->finish();

			$customerList =~ s/,$//;
			if (length($customerList) > 0) {

				$sql = $archObj->processSQL("UPDATE transactivity, specificproduct SET transactivity.closeddatevendinv = '$val_INDEF', transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND (transactivity.closeddatevendinv IS NULL OR transactivity.closeddatevendinv = '0000-00-00') AND (transactivity.unitsalesvend IS NULL OR transactivity.unitsalesvend = 0) AND transactivity.type IN ('DE', 'PU', 'AD') AND transactivity.specificproductid = specificproduct.recid AND specificproduct.productid = '$productId' AND transactivity.locationid = '$clientLocId' AND transactivity.customerlocid IN ($customerList) AND specificproduct.datex <= '$endingDate'");
				print "$sql\n" if ($debug);
				$dbh->do($sql) or die "$sql;\n";
			}


#			$sql = "SELECT recid, billingflag FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$vendorLocId' AND invdate = '". $runDate->getDate() ."' AND periodenddate = '$endingDate' AND type = 'I' AND source = 'F' AND productid = '$productId'";
			$sql = "SELECT recid, billingflag, invdate FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$vendorLocId' AND periodenddate = '$endingDate' AND type = 'I' AND source = 'F' AND productid = '$productId'";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my ($piRecId, $piBillingFlag, $invDate) = $sth->fetchrow_array();
			$sth->finish();

			if (($piBillingFlag eq "Y" || $piBillingFlag eq "P") && length($piRecId) > 0 && $piRecId > 0) {
				next;
			}


			my $rowsUpdated = 0;
			if ($prodLag eq "N") {
				my $startDate = getStartingDate($period, $endingDate, $feePeriodDaycodeId, $feePeriodBaseDate);

				$sql = "SELECT recid FROM specificproduct WHERE productid = '$productId' AND datex >= '$startDate' AND datex <= '$endingDate'";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my ($spProdId) = $sth->fetchrow_array();
				$sth->finish();

				$sql = $archObj->processSQL("SELECT COUNT(*) FROM transactivity WHERE recid <= '$maxTaRecId' AND locationid = '$clientLocId' AND type = 'SD' AND (closeddatevend IS NULL OR closeddatevend = '0000-00-00' OR closeddatevend = '$invDate') AND specificproductid = '$spProdId'");
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my ($isSDExists) = $sth->fetchrow_array();
				$sth->finish();

				if ($isSDExists) {
					$sql = "SELECT sp1.recid FROM specificproduct sp, specificproduct sp1 WHERE sp.recid = '$spProdId' AND sp.productid = sp1.productid AND sp1.datex < sp.datex ORDER BY sp1.datex DESC LIMIT 1";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my ($prevSPId) = $sth->fetchrow_array();

					if (length($piRecId) > 0 && $piRecId > 0) {
						$sql = $archObj->processSQL("UPDATE transactivity SET closeddatevendinv = '". $runDate->getDate() ."', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid <= '$maxTaRecId' AND locationid = '$clientLocId' AND type IN ('DE', 'PU', 'AD') AND (closeddatevendinv IS NULL OR closeddatevendinv = '0000-00-00' OR closeddatevendinv = '$invDate') AND specificproductid = '$prevSPId'");
					} else {
						$sql = $archObj->processSQL("UPDATE transactivity SET closeddatevendinv = '". $runDate->getDate() ."', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid <= '$maxTaRecId' AND locationid = '$clientLocId' AND type IN ('DE', 'PU', 'AD') AND (closeddatevendinv IS NULL OR closeddatevendinv = '0000-00-00') AND specificproductid = '$prevSPId'");
					}
					print "$sql\n" if ($debug);
					$rowsUpdated = $dbh->do($sql) or die "$sql;\n";

				}
			} elsif ($prodLag eq "R") {
				my $startDate = getStartingDate($period, $endingDate, $feePeriodDaycodeId, $feePeriodBaseDate);

				my $spProdIds;
				$sql = $archObj->processSQL("SELECT DISTINCT ta.specificproductid FROM transactivity ta, specificproduct sp WHERE ta.recid <= '$maxTaRecId' AND ta.locationid = '$clientLocId' AND ta.type = 'SP' AND ta.specificproductid = sp.recid AND sp.productid = '$productId' AND ta.datex >= '$startDate' AND ta.datet <= '$endingDate'");
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				while (my ($val) = $sth->fetchrow_array()) {
					$spProdIds .= length($spProdIds) == 0 ? $val : "," . $val;
				}
				$sth->finish();

				if (length($spProdIds) > 0) {
					if (length($piRecId) > 0 && $piRecId > 0) {
						$sql = $archObj->processSQL("UPDATE transactivity SET closeddatevendinv = '". $runDate->getDate() ."', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid <= '$maxTaRecId' AND locationid = '$clientLocId' AND type IN ('DE', 'PU', 'AD') AND (closeddatevendinv IS NULL OR closeddatevendinv = '0000-00-00' OR closeddatevendinv = '$invDate') AND specificproductid IN ($spProdIds)");
					} else {
						$sql = $archObj->processSQL("UPDATE transactivity SET closeddatevendinv = '". $runDate->getDate() ."', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid <= '$maxTaRecId' AND locationid = '$clientLocId' AND type IN ('DE', 'PU', 'AD') AND (closeddatevendinv IS NULL OR closeddatevendinv = '0000-00-00') AND specificproductid IN ($spProdIds)");
					}
					print "$sql\n" if ($debug);
					$rowsUpdated = $dbh->do($sql) or die "$sql;\n";
				}

			} else {

				if (length($piRecId) > 0 && $piRecId > 0) {
					$sql = $archObj->processSQL("UPDATE transactivity, specificproduct, product SET transactivity.closeddatevendinv = '". $runDate->getDate() ."', transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.locationid = '$clientLocId' AND transactivity.type IN ('DE', 'PU', 'AD') AND (transactivity.closeddatevendinv IS NULL OR transactivity.closeddatevendinv = '0000-00-00' OR transactivity.closeddatevendinv = '$invDate') AND specificproduct.recid = transactivity.specificproductid AND product.recid = specificproduct.productid AND product.recid = '$productId' AND specificproduct.datex <= DATE_SUB('$endingDate', INTERVAL $prodLag DAY)");
				} else {
					$sql = $archObj->processSQL("UPDATE transactivity, specificproduct, product SET transactivity.closeddatevendinv = '". $runDate->getDate() ."', transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.locationid = '$clientLocId' AND transactivity.type IN ('DE', 'PU', 'AD') AND (transactivity.closeddatevendinv IS NULL OR transactivity.closeddatevendinv = '0000-00-00') AND specificproduct.recid = transactivity.specificproductid AND product.recid = specificproduct.productid AND product.recid = '$productId' AND specificproduct.datex <= DATE_SUB('$endingDate', INTERVAL $prodLag DAY)");
				}
				print "$sql\n" if ($debug);
				$rowsUpdated = $dbh->do($sql) or die "$sql;\n";
			}


			if ($rowsUpdated > 0) {

				# amout for DE & AD Records.
				$sql = $archObj->processSQL("SELECT SUM(ta.actquantity * ta.unitsalesvend) as deamount FROM transactivity ta, specificproduct sp WHERE ta.recid <= '$maxTaRecId' AND ta.locationid = '$clientLocId' AND (ta.type = 'DE' OR ta.type = 'AD') AND ta.closeddatevendinv = '". $runDate->getDate() ."' AND sp.recid = ta.specificproductid AND sp.productid = '$productId' AND sp.datex <= '$endingDate'");
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my $deAmount = ($sth->fetchrow_array())[0];
				$sth->finish();

				# amount for PU records
				$sql = $archObj->processSQL("SELECT SUM(ta.actquantity * ta.unitsalesvend) as deamount FROM transactivity ta, specificproduct sp WHERE ta.recid <= '$maxTaRecId' AND ta.locationid = '$clientLocId' AND ta.type = 'PU' AND ta.closeddatevendinv = '". $runDate->getDate() ."' AND sp.recid = ta.specificproductid AND sp.productid = '$productId' AND sp.datex <= '$endingDate'");
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my $puAmount = ($sth->fetchrow_array())[0];
				$sth->finish();

				my $vendorAmount = $deAmount - $puAmount;
				$vendorAmount = sprintf("$format",$vendorAmount);

				if (length($piRecId) > 0 && $piRecId > 0) {
					$sql = "UPDATE productinvoice SET totalamount = '$vendorAmount', invdate = '". $runDate->getDate() ."', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE  recid = '$piRecId'";
					print "$sql\n" if ($debug);
					$dbh->do($sql) or die "$sql;\n";
				} else {
					$sql = "INSERT INTO productinvoice(clientlocid, customerlocid, type, productid, invdate, periodenddate, totalamount, billingflag, source) values('$clientLocId', '$vendorLocId', 'I', '$productId','". $runDate->getDate() ."', '$endingDate', '$vendorAmount', 'N', 'F')";
					print "$sql\n" if ($debug);
					$dbh->do($sql) or die "$sql;\n";
					my $productInvoiceId = $dbh->{'mysql_insertid'};
					
					#/* Task#8394 Starts*/
					if($productInvoiceId) {
						if($char_SUMTA eq 'Y') {
							cvt_general::insertInvoiceTaLinkProductInvoice($dbh, $clientId, $clientLocId, $vendorLocId, $productId, 'F', 'I', $endingDate, $runDate->getDate(), $productInvoiceId, 'SE024');
						}
					}
					#/* Task#8394 Ends*/
				}

				$invoicedPDEndDate .= length($invoicedPDEndDate) == 0 ? $endingDate : "," . $endingDate;
			}
		}
	} # END OF WHILE LOOP
}


sub processServiceChargeCust {

	my ($clientId, $clientLocId) = @_;
	my $Email_Inv = 0; #Task#8840
	if(length($clientId) == 0 || length ($clientLocId) == 0 || length($runDate->getDate()) == 0) {
		print "Not adequate data\n";
		return ;
	}
	
	my $full_Path = "/usr/local/apache/htdocs/twce/cm/";
	my $scriptName = "piafunc.php";
	my $called_from = "SE024";
	my $_cutOffDate = "0000-00-00";
	my $_RunDate = $runDate->getDate();
	my $ProdInvRecId = 0;	
	 
	#swapnil:
	#task 100:
	$sql = "SELECT charvar FROM locationsystem WHERE recid = 'SCTPC' AND locationid = '$clientLocId'";
	$sth = $dbh->prepare($sql);
	$sth->execute() || die "$sql\n";
	my $sctpc = ($sth->fetchrow_array)[0];
	$sth->finish();
	createPCServiceChargeCust($clientId, $clientLocId,$sctpc);
	createLIServiceChargeCust($clientId, $clientLocId); #Task#8756
	
	
	$sql = $archObj->processSQL("SELECT MAX(recid) FROM transactivitysc WHERE locationid = '$clientLocId'");
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	($maxTaSCRecId) = $sth->fetchrow_array();
	$sth->finish();

	if (length($maxTaSCRecId) == 0) {
		$maxTaSCRecId = 0;
	}
	#finish :task# 100:
	
	$sql = "SELECT DISTINCT(sc.customerlocid), l.effdate, l.endeffdate FROM servicecharge sc, location l WHERE sc.clientlocid = '$clientLocId' AND sc.customerlocid > 0 AND sc.customerlocid = l.recid";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $rows = $sth->rows();
	my $refLocations = $sth->fetchall_arrayref();
	$sth->finish();

	my @custLocations = @$refLocations;

	#$sql = $archObj->processSQL("SELECT DISTINCT(customerlocid) FROM transactivitysc WHERE locationid = '$clientLocId' AND (customerlocid IS NOT NULL AND customerlocid > 0) AND (servicechargeid IS NULL OR servicechargeid = '0000-00-00') AND type IN ('BD', 'PF', 'DP', 'SF', 'VF', 'VR', 'VC', 'DF', 'DS', 'PS','CD','IP','IQ','IT','IB','IC','IG','IM','IA','IX','IF','IL','ID','IS','IY','PU','ST') AND (closeddatecust IS NULL OR closeddatecust = '0000-00-00')");
	#swapnil:
	#task 100: change the condition so that it could consider the servicecharge.serviceid
	$sql = "SELECT charvar FROM locationsystem WHERE recid = 'SCTDF' AND locationid = '$clientLocId'";
	$sth = $dbh->prepare($sql);
	$sth->execute() || die "$sql\n";
	my $sctdf = ($sth->fetchrow_array)[0];
	$sth->finish();
	if($sctdf eq "Y" || $sctpc eq "Y" ){
		$sql = $archObj->processSQL("SELECT /*SE024*/ customerlocid FROM transactivitysc WHERE locationid = '$clientLocId' AND (customerlocid IS NOT NULL AND customerlocid > 0) AND type IN ('BD', 'PF', 'DP', 'SF', 'VF', 'VR', 'VC', 'DF', 'DS', 'PS','PC','CD','IP','IQ','IT','IB','IC','IG','IM','IA','IX','IF','IL','ID','IS','IY','PU','ST','IE','LI') AND (closeddatecust IS NULL OR closeddatecust = '0000-00-00')");#Task#8756
		
		
	}else {
		$sql = $archObj->processSQL("SELECT /*SE024*/ DISTINCT(customerlocid) FROM transactivitysc WHERE locationid = '$clientLocId' AND (customerlocid IS NOT NULL AND customerlocid > 0) AND (servicechargeid IS NULL OR servicechargeid = '0000-00-00') AND type IN ('BD', 'PF', 'DP', 'SF', 'VF', 'VR', 'VC', 'DF', 'DS', 'PS','CD','IP','IQ','IT','IB','IC','IG','IM','IA','IX','IF','IL','ID','IS','IY','PU','ST','IE','LI') AND (closeddatecust IS NULL OR closeddatecust = '0000-00-00')");#Task#8756
		
	}
	
	##task# -100 -finish

	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	$rows = $sth->rows();
	my $refManLocations = $sth->fetchall_arrayref();
	$sth->finish();
	if ($rows > 0) {
		push @custLocations, @{$refManLocations};
	}

	foreach my $record (@custLocations) {
		#my $customerLocId = $record->[0];
		my ($customerLocId, $customerEffDt, $customerEndeffdt) = @{$record};
		if (length (cvt_general::trim($customerLocId)) == 0) {
			$customerLocId = 0;
		}
		
		if (length (cvt_general::trim($customerEndeffdt)) == 0) {
			$customerEndeffdt = '0000-00-00';
		}

		$sql = "SELECT scdaycodeid, basescdate, scperioddaycodeid, basescperioddate, piaflag FROM routelink WHERE clientid = '$clientId' and locationid = '$customerLocId' AND (scdaycodeid IS NOT NULL AND scdaycodeid > 0) AND (scperioddaycodeid IS NOT NULL AND scperioddaycodeid > 0)";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my ($billDaycodeId, $billBaseDate, $billPeriodDaycodeId, $billPeriodBaseDate, $piaFlag) = $sth->fetchrow_array();
		$sth->finish();
			
		if ($piaFlag eq "N") {
		print "PIA-FLG is N so Skipp\n";
			next ;
		}
		
		$sql = "SELECT invoicemethod FROM routelink LEFT JOIN daycode dc on billingperioddaycodeid = dc.recid  WHERE clientid = '$clientId' and locationid = '$customerLocId' AND (billingdaycodeid IS NOT NULL AND billingdaycodeid > 0) AND (billingperioddaycodeid IS NOT NULL AND billingperioddaycodeid > 0) ";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my ($InvoiceMethod) = $sth->fetchrow_array();
		$sth->finish();
		
		if($InvoiceMethod eq 'N')
		{
		  print " \n Don't process invoice \n";
		  next;
		}
				
		my $isBillingDay = isLocationOpen($runDate->getDate(), $billDaycodeId, $billBaseDate, $billPeriodDaycodeId, $billPeriodBaseDate);

		if ($isBillingDay == 0) {
			next ;
		}

		$sql = "SELECT type, period, sequence FROM daycode WHERE recid = '$billDaycodeId'";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my ($type, $period, $sequence) = $sth->fetchrow_array();
		$sth->finish();

		# WHEN TYPE IS "L" THEN CHANGE THE RUNDATE BACK TO THE RELATIVE DAYS FOR THE BILLINGDAYCODEID
		my $tempRunDate = '';
		if($type eq "L"){
			$tempRunDate = $runDate->getDate();
			# Finding the lagging period
			my $lag = $sequence * 7;
			$runDate->setDate($runDate->addDaysToDate($lag * -1));

		} # end of lagging period condition.

		my $endingDate;
		if($val_MANAR > 0) {
			$sql = "SELECT periodenddate FROM ".$archObj->archDB.".productpayables WHERE clientlocid = '$clientLocId' AND vendorlocid = '$customerLocId' AND type = 'I' AND source = 'S' ORDER BY periodenddate DESC LIMIT 1";
			$sth = $dbh->prepare($sql);
			$sth->execute() || die "$sql;\n";
			my ($latestPDEndDate) = $sth->fetchrow_array();
			$sth->finish();

			if(length($latestPDEndDate) == 0) {
				$endingDate = getEndingDate($period, $runDate->getDate(), $billPeriodDaycodeId, $billPeriodBaseDate);
			} else {
				$latestPDEndDate = cvt_general::DateOperation($latestPDEndDate, 1, "ADD");
				my $nextPDEndDate = getFutureEndDateFromStartDate($latestPDEndDate, $billPeriodDaycodeId, $billPeriodBaseDate);
				if($nextPDEndDate ge $runDate->getDate()) {
					$latestPDEndDate = cvt_general::DateOperation($latestPDEndDate, 1, "SUB");
					$endingDate = $latestPDEndDate;
				} else {
					$endingDate = $nextPDEndDate;
				}
			}
		} else {
			$endingDate = getEndingDate($period, $runDate->getDate(), $billPeriodDaycodeId, $billPeriodBaseDate);
			print "isBillingDay:$isBillingDay\nendingDate:$endingDate\n" if($debug);
			if ($isBillingDay =~ /-/) {
				$endingDate = $isBillingDay;
			}
		}

		print "EndingDate: $endingDate\n" if ($debug);
		if (length($endingDate) == 0) {
			#Billing date not found move to next location
			next ;
		}

		if (length($tempRunDate) > 0) {
			$runDate->setDate($tempRunDate);
			$tempRunDate = '';
		}

		# PROCESS OF THE TRANSACTION RECORDS FOR WHICH CLOSEDDATECUST IS NULL OR ZERO.
		# Bill To Customer Case

		my $totalAmount = 0;

		#'BD', 'PF', 'DF', 'DP', 'SF', 'VF', 'VR', 'VC'
		#swapnil: add the 'PC' in the query 
		$sql = $archObj->processSQL("SELECT /*SE024*/ COUNT(*) FROM transactivitysc ta WHERE ta.recid <= '$maxTaSCRecId' AND ta.type IN ('BD', 'PF', 'DP', 'SF', 'VF', 'VR', 'VC', 'DF', 'DS', 'PS','PC','CD','IP','IQ','IT','IB','IC','IG','IM','IA','IX','IF','IL','ID','IS','IY','PU','ST','IE','LI') AND (ta.closeddatecust IS NULL OR ta.closeddatecust = '0000-00-00') AND ta.datet <= '$endingDate' AND ta.customerlocid = '$customerLocId' AND ta.locationid = '$clientLocId'"); #Task#8756
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my $isRecordExists = ($sth->fetchrow_array())[0];
		$sth->finish();

		my $billingFlag = "N";
		if ($piaFlag eq "Y") {
			$billingFlag = "Y";
		}

		if ($isRecordExists > 0) {

			$sql = "SELECT recid, billingflag, invdate FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND periodenddate = '$endingDate' AND type = 'I' AND source = 'S' ";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my ($piRecId, $piBillingFlag, $invDate) = $sth->fetchrow_array();
			$sth->finish();

			if ((($piBillingFlag eq "Y" && $billingFlag eq "N") || $piBillingFlag eq "P") && length($piRecId) > 0 && $piRecId > 0) {
				next;
			}

			my $row = 0;
			#swapnil: add the 'PC' in the query 
			if (length($piRecId) > 0 && length($invDate) > 0) {
				$sql = $archObj->processSQL("UPDATE /*SE024*/ transactivitysc ta SET ta.closeddatecust = '". $runDate->getDate() ."', ta.archupdt = IF(ta.archupdt = 'P', 'U', ta.archupdt) WHERE ta.recid <= '$maxTaSCRecId' AND ta.type IN ('DF', 'BD', 'PF', 'DP', 'SF', 'VF', 'VR', 'VC', 'DS', 'PS','PC','CD','IP','IQ','IT','IB','IC','IG','IM','IA','IX','IF','IL','ID','IS','IY','PU','ST','IE','LI') AND (ta.closeddatecust IS NULL OR ta.closeddatecust = '0000-00-00' OR ta.closeddatecust = '$invDate') AND ta.datet <= '$endingDate' AND ta.customerlocid = '$customerLocId' AND ta.locationid = '$clientLocId'"); #Task#8756
				print "$sql\n" if ($debug);
				$row = $dbh->do($sql) or die "$sql;\n";
			} else {
				$sql = $archObj->processSQL("UPDATE /*SE024*/ transactivitysc ta SET ta.closeddatecust = '". $runDate->getDate() ."', ta.archupdt = IF(ta.archupdt = 'P', 'U', ta.archupdt) WHERE ta.recid <= '$maxTaSCRecId' AND ta.type IN ('DF', 'BD', 'PF', 'DP', 'SF', 'VF', 'VR', 'VC', 'DS', 'PS','PC','CD','IP','IQ','IT','IB','IC','IG','IM','IA','IX','IF','IL','ID','IS','IY','PU','ST','IE','LI') AND (ta.closeddatecust IS NULL OR ta.closeddatecust = '0000-00-00') AND ta.datet <= '$endingDate' AND ta.customerlocid = '$customerLocId' AND ta.locationid = '$clientLocId'");#Task#8756
				print "$sql\n" if ($debug);
				$row = $dbh->do($sql) or die "$sql;\n";
			}


			# Calculate various type's of amount
			if ($row > 0) {
				
				#swapnil: add the 'PC' in the query 
				$sql = $archObj->processSQL("SELECT /*SE024*/ SUM(actquantity * unitsales) as desum FROM transactivitysc WHERE recid <= '$maxTaSCRecId' AND customerlocid = '$customerLocId' AND locationid = '$clientLocId' AND closeddatecust = '". $runDate->getDate() ."' AND type IN ('BD', 'PF', 'DF', 'DP', 'SF', 'VF', 'VR', 'VC', 'DS', 'PS','PC','CD','IP','IQ','IT','IB','IC','IG','IM','IA','IX','IF','IL','ID','IS','IY','PU','ST','IE','LI')");#Task#8756
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my $amount = ($sth->fetchrow_array())[0];
				$sth->finish();
				$amount = sprintf("$format",$amount);

				my $_fromDate = "0000-00-00";
				# NOW INSERT A RECORD INTO THE PRODUCTINVOICE FOR INVOICING
				#if ($amount > 0) {
					if (length($piRecId) > 0 && $piRecId > 0) {
						$sql = "UPDATE productinvoice SET totalamount = '$amount', invdate = '". $runDate->getDate() ."', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE  recid = '$piRecId'";
						print "$sql\n" if ($debug);
						$dbh->do($sql) or die "$sql;\n";
						$ProdInvRecId = $piRecId;
						if ($piaFlag eq "Y") {
							$sql = "SELECT COUNT(*) FROM productinvoice WHERE periodenddate = '$endingDate' AND type = 'D' AND source = 'S' and clientlocid = '$clientLocId' AND customerlocid = '$customerLocId'";
							print "$sql\n" if ($debug);
							$sth = $dbh->prepare($sql);
							$sth->execute() or die "$sql;\n";
							my $duplicate = ($sth->fetchrow_array())[0];
							$sth->finish();

							if (!$duplicate) {
								print "sbz 9\n";
								print "cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerLocId $endingDate $billPeriodDaycodeId $_cutOffDate $customerEffDt $customerEndeffdt $_fromDate 0000-00-00 0 0 $called_from D S $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \r\n" if (1);
								system("cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerLocId $endingDate $billPeriodDaycodeId $_cutOffDate $customerEffDt $customerEndeffdt $_fromDate 0000-00-00 0 0 $called_from D S $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \&");
							}
						}
						
					} else {
											my $val_ADPMT = "0";
                                       		$sql = "SELECT DISTINCT(locationid) FROM locationsystem WHERE recid = 'ADPMT' AND locationid = $clientLocId AND charvar = 'Y' AND (endeffdt = '0000-00-00' OR endeffdt is null OR endeffdt > '". $runDate->getDate() ."')";
	                                        print "$sql\n" if ($debug);
	                                        $sth = $dbh->prepare($sql);
	                                        $sth->execute() or die "$sql;\n";
                                               	$val_ADPMT = $sth->rows();
	                                        $sth->finish();

                                                        $sql = "INSERT INTO productinvoice(clientlocid, customerlocid, type, invdate, periodenddate, totalamount, billingflag, source) values('$clientLocId', '$customerLocId', 'I', '". $runDate->getDate() ."', '$endingDate', '$amount', '$billingFlag', 'S')";
	                                                print "$sql\n" if ($debug);
	                                                $dbh->do($sql) or die "$sql;\n";
										$ProdInvRecId = $dbh->{'mysql_insertid'};			
													
									if ($piaFlag eq "Y") {
										print "sbz 10\n";
										#print "cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerLocId $endingDate $billPeriodDaycodeId $_cutOffDate $customerEffDt $customerEndeffdt $_fromDate 0000-00-00 0 0 $called_from I S $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \r\n" if (1);
										#system("cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerLocId $endingDate $billPeriodDaycodeId $_cutOffDate $customerEffDt $customerEndeffdt $_fromDate 0000-00-00 0 0 $called_from I S $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \&");
										#point 2
									}
													
#                  					my $productInvoiceId = $dbh->{'mysql_insertid'};
									
                                                if($val_ADPMT > 0) {
	                                                my $val_PRODP = "0";
	                                                $sql = "SELECT realvar FROM locationsystem WHERE recid = 'PRODP' AND locationid = '$clientLocId' AND (endeffdt = '0000-00-00' OR endeffdt is null OR endeffdt > '". $runDate->getDate() ."')";
	                                                print "$sql\n" if ($debug);
	                                                $sth = $dbh->prepare($sql);
	                                                $sth->execute() or die "$sql;\n";
                                                        $val_PRODP = ($sth->fetchrow_array())[0];
	                                                $sth->finish();


	                                                $sql = "SELECT SUM(totalamount),periodenddate FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type IN('P','C') AND billingflag = 'Y' AND source = 'S' GROUP BY periodenddate";
	                                                print "$sql\n" if ($debug);
	                                                $sth = $dbh->prepare($sql);
	                                                $sth->execute() or die "$sql;\n";
			                                while (my ($chkTotalAmount,$periodenddate) = $sth->fetchrow_array()) {

													my $abschkTotalAmount = abs($chkTotalAmount);
													my $maxprodp = $abschkTotalAmount + $val_PRODP;
													my $minprodp = $abschkTotalAmount - $val_PRODP;

													$sql = "UPDATE productinvoice SET billingflag = 'Y' WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type = 'I' AND source = 'S' AND periodenddate = '$periodenddate' ";
                                                    print "$sql\n" if ($debug);
                                                    $dbh->do($sql) or die "$sql;\n";

													$sql = "SELECT SUM(totalamount) FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type = 'I' AND billingflag = 'Y' AND source = 'S' AND totalamount < $maxprodp AND totalamount > $minprodp AND periodenddate = '$periodenddate' GROUP BY periodenddate";
	                                                print "$sql\n" if ($debug);
	                                                $sth = $dbh->prepare($sql);
	                                                $sth->execute() or die "$sql;\n";
													my $iexist = $sth->rows();


                                                        $chkTotalAmount = abs($chkTotalAmount);
                                                        if($iexist > 0) {

                                                        my $locAmtDiff = $chkTotalAmount;

	                                                        $sql = "UPDATE productinvoice SET billingflag = 'P' WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type IN('P','C') AND periodenddate = '$periodenddate' AND billingflag = 'Y' AND source = 'S'";
	                                                        print "$sql\n" if ($debug);
	                                                        $dbh->do($sql) or die "$sql;\n";

															$sql = "UPDATE productinvoice SET billingflag = 'P' WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type = 'I' AND billingflag = 'Y' AND source = 'S' AND periodenddate = '$periodenddate' ";
															print "$sql\n" if ($debug);
															$dbh->do($sql) or die "$sql;\n";

                                                        	}
                                                           }
                                                          $sth->finish();
                                                	}
													
					}
				#}
                 my $InvoiceDate = $runDate->getDate();
					if($ProdInvRecId)
					{
						$Email_Inv = 1; #Task#8840
						print "\n----trigger createInvoiceTaLink Function------\n";
						cvt_general::createInvoiceTaLink($dbh,'transactivitysc','closeddatecust',$clientId,$clientLocId,$customerLocId,$InvoiceDate,$ProdInvRecId,$endingDate,'S','1',"'BD', 'PF', 'DF', 'DP', 'SF', 'VF', 'VR', 'VC', 'DS', 'PS','PC','CD','IP','IQ','IT','IB','IC','IG','IM','IA','IX','IF','IL','ID','IS','IY','PU','ST','IE','LI'",'SE024','',''); #Task#8756
					}
				$invoicedPDEndDate .= length($invoicedPDEndDate) == 0 ? $endingDate : "," . $endingDate;
			}
		}


		# Pay To Customer Case
		my $deAmount = 0;
		my $puAmount = 0;
		$totalAmount = 0;

		$sql = $archObj->processSQL("SELECT COUNT(*) FROM transactivitysc ta WHERE ta.recid <= '$maxTaSCRecId' AND ta.type IN ('BD', 'PF', 'DF', 'DP', 'SF', 'VF', 'VR', 'VC', 'DS', 'PS','CD','IP','IQ','IT','IB','IC','IG','IM','IA','IX','IF','IL','ID','IS','IY','PU','ST','IE') AND (ta.closeddatecustpay IS NULL OR ta.closeddatecustpay = '0000-00-00') AND ta.datet <= '$endingDate' AND ta.customerlocid = '$customerLocId' AND ta.locationid = '$clientLocId'");
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my $isExists = ($sth->fetchrow_array())[0];
		$sth->finish();

		if ($isExists > 0) { 

			$sql = "SELECT recid, billingflag, payabledate FROM productpayables WHERE clientlocid = '$clientLocId' AND vendorlocid = '$customerLocId' AND periodenddate = '$endingDate' AND type = 'I' AND source = 'S'";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my ($productPayRecId, $productPayableBillingFlag, $invDate) = $sth->fetchrow_array();
			$sth->finish();

			if (($productPayableBillingFlag eq "Y" || $productPayableBillingFlag eq "P") && length($productPayRecId) > 0 && $productPayRecId > 0) {
				next;
			}

			if (length($productPayRecId) > 0 && $productPayRecId > 0) {
				$sql = $archObj->processSQL("UPDATE transactivitysc SET closeddatecustpay = '". $runDate->getDate() ."', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid <= '$maxTaSCRecId' AND type IN ('BD', 'PF', 'DF', 'DP', 'SF', 'VF', 'VR', 'VC', 'DS', 'PS','CD','IP','IQ','IT','IB','IC','IG','IM','IA','IX','IF','IL','ID','IS','IY','PU','ST','IE') AND (closeddatecustpay IS NULL OR closeddatecustpay = '0000-00-00' OR closeddatecustpay = '$invDate') AND datet <= '$endingDate' AND customerlocid = '$customerLocId' AND locationid = '$clientLocId'");
			} else {
				$sql = $archObj->processSQL("UPDATE transactivitysc SET closeddatecustpay = '". $runDate->getDate() ."', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid <= '$maxTaSCRecId' AND type IN ('BD', 'PF', 'DF', 'DP', 'SF', 'VF', 'VR', 'VC', 'DS', 'PS','CD','IP','IQ','IT','IB','IC','IG','IM','IA','IX','IF','IL','ID','IS','IY','PU','ST','IE') AND (closeddatecustpay IS NULL OR closeddatecustpay = '0000-00-00') AND datet <= '$endingDate' AND customerlocid = '$customerLocId' AND locationid = '$clientLocId'");
			}
			print "$sql\n" if ($debug);
			my $row = $dbh->do($sql) or die "$sql;\n";

			# Calculate the Amount
			if ($row > 0) {

				$sql = $archObj->processSQL("SELECT SUM(ta.actquantity * ta.unitcostcust) as desum FROM transactivitysc ta WHERE ta.recid <= '$maxTaSCRecId' AND ta.datet <= '$endingDate' AND ta.closeddatecustpay = '". $runDate->getDate() ."' AND ta.type IN ('BD', 'PF', 'DF', 'DP', 'SF', 'VF', 'VR', 'VC', 'DS', 'PS','CD','IP','IQ','IT','IB','IC','IG','IM','IA','IX','IF','IL','ID','IS','IY','PU','ST','IE') AND ta.customerlocid = '$customerLocId' AND ta.locationid = '$clientLocId'");
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my $amount = ($sth->fetchrow_array())[0];
				$sth->finish();

				$amount = sprintf("$format",$amount);
				if ($amount > 0) {
					$amount = $amount * -1;
					if (length($productPayRecId) > 0 && $productPayRecId > 0) {
						$sql = "UPDATE productpayables SET totalamount = '$amount', payabledate = '". $runDate->getDate() ."', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE  recid = '$productPayRecId'";
						print "$sql\n" if ($debug);
						$dbh->do($sql) or die "$sql;\n";
					} else {
						# NOW INSERT A RECORD INTO THE PRODUCTPAYABLES FOR PAYING
						
							$sql = "INSERT INTO productpayables(clientlocid, vendorlocid, type, payabledate, periodenddate, totalamount, billingflag, source) values('$clientLocId', '$customerLocId', 'I', '". $runDate->getDate() ."', '$endingDate', $amount, 'N', 'S')";
							print "$sql\n" if ($debug);
							$dbh->do($sql) or die "$sql;\n";
							$Email_Inv = 1; #Task#8840
					}

					$invoicedPDEndDate .= length($invoicedPDEndDate) == 0 ? $endingDate : "," . $endingDate;
				}
			}
		}
	}
	return $Email_Inv; #Task#8840
}

sub processServiceChargeVend {
	my ($clientId ,$clientLocId) = @_;
	$sql = "SELECT distinct (p.recid), p.scdaycodeid, p.basescdate, p.scperioddaycodeid, p.basescperioddate, p.vendorlocid FROM product p, servicecharge sc WHERE sc.clientlocid = '$clientLocId' AND sc.productid = p.recid AND p.clientid = '$clientId' /*AND p.producttype = 'PU'*/ AND p.vendorlocid > 0 AND (p.scdaycodeid IS NOT NULL AND p.scdaycodeid > 0) AND (p.scperioddaycodeid IS NOT NULL AND p.scperioddaycodeid > 0) ";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $rows = $sth->rows();
	my $refVendorLocs = $sth->fetchall_arrayref();
	$sth->finish();

	my @vendorLocs = @$refVendorLocs;

	$sql = $archObj->processSQL("SELECT DISTINCT(specificproductid) FROM transactivitysc WHERE locationid = '$clientLocId' AND type IN ('BD', 'PF', 'DP', 'DF', 'SF', 'VF', 'VR', 'VC', 'DS', 'DP','CD','IP','IQ','IT','IB','IC','IG','IM','IA','IX','IF','IL','ID','IS','IY','PU','ST','IE') AND (closeddatevendinv IS NULL OR closeddatevendinv = '0000-00-00')");
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	$rows = $sth->rows();
	my $refSpProductIds = $sth->fetchall_arrayref();
	$sth->finish();
	my $spProductIds = "";
	foreach my $rec (@{$refSpProductIds}) {
		if (length($rec->[0]) > 0) {
			if (length($spProductIds) == 0) {
				$spProductIds = $rec->[0];
			} else {
				$spProductIds .= "," . $rec->[0];
			}
		}
	}
	if (length($spProductIds) > 0) {
		$sql = "SELECT distinct (p.recid), p.scdaycodeid, p.basescdate, p.scperioddaycodeid, p.basescperioddate, p.vendorlocid FROM specificproduct sp, product p WHERE sp.recid IN ($spProductIds) AND sp.productid = p.recid AND (p.endeffdt IS NULL OR p.endeffdt = '0000-00-00' OR p.endeffdt > NOW())";
		print "$sql\n" if($debug);
		$sth = $dbh->prepare($sql) or die "$sql\n";
		$sth->execute() or die "$sql\n";
		my ($refVendorLocs) = $sth->fetchall_arrayref();
		$sth->finish();
		foreach  (@{$refVendorLocs}) {
			push @vendorLocs, $_;
		}
	}

	my $runDateDOW = $runDate->getDayOfWeek();
	my $monthEndDate = $runDate->getMonthEndDate();

	foreach my $record (@vendorLocs) {
		my ($productId, $billDaycodeId, $billBaseDate, $billPeriodDaycodeId, $billPeriodBaseDate, $vendorLocId) = @{$record};

		my $isLocationOpen = isLocationOpen($runDate->getDate(), $billDaycodeId, $billBaseDate, $billPeriodDaycodeId, $billPeriodBaseDate);

		if ($isLocationOpen == 0) {
			next ;
		}

		$sql = "SELECT type, period, sequence FROM daycode WHERE recid = '$billDaycodeId'";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my ($type, $period, $sequence) = $sth->fetchrow_array();
		$sth->finish();

		# WHEN TYPE IS "L" THEN CHANGE THE RUNDATE BACK TO THE RELATIVE DAYS FOR THE BILLINGDAYCODEID
		my $tempRunDate = '';
		if($type eq "L"){
			$tempRunDate = $runDate->getDate();
			# Finding the lagging period
			my $lag = $sequence * 7;
			$runDate->setDate($runDate->addDaysToDate($lag * -1));

		} # end of lagging period condition.


		my $endingDate;
		if($val_MANAR > 0) {
			$sql = "SELECT periodenddate FROM ".$archObj->archDB.".productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$vendorLocId' AND type = 'I' AND source = 'P' ORDER BY periodenddate DESC LIMIT 1";
			$sth = $dbh->prepare($sql);
			$sth->execute() || die "$sql;\n";
			my ($latestPDEndDate) = $sth->fetchrow_array();
			$sth->finish();

			if(length($latestPDEndDate) == 0) {
				$endingDate = getEndingDate($period, $runDate->getDate(), $billPeriodDaycodeId, $billPeriodBaseDate);
			} else {
				$latestPDEndDate = cvt_general::DateOperation($latestPDEndDate, 1, "ADD");
				my $nextPDEndDate = getFutureEndDateFromStartDate($latestPDEndDate, $billPeriodDaycodeId, $billPeriodBaseDate);
				if($nextPDEndDate ge $runDate->getDate()) {
					$latestPDEndDate = cvt_general::DateOperation($latestPDEndDate, 1, "SUB");
					$endingDate = $latestPDEndDate;
				} else {
					$endingDate = $nextPDEndDate;
				}
			}
		} else {
			$endingDate = getEndingDate($period, $runDate->getDate(), $billPeriodDaycodeId, $billPeriodBaseDate);
			print "isLocationOpen:$isLocationOpen\nendingDate:$endingDate\n" if($debug);
			if ($isLocationOpen =~ /-/) {
				$endingDate = $isLocationOpen;
			}
		}

		print "ending_date:$endingDate\n" if ($debug);

		if(length($tempRunDate) > 0) {
			$runDate->setDate($tempRunDate);
			$tempRunDate = '';
		}

		if (length($endingDate) > 0) {
#			$sql = "SELECT recid, billingflag FROM productinvoice WHERE clientlocid = '$clientLocId' AND invdate = ". $runDate->getDate() ." AND periodenddate = '$endingDate' AND type = 'I' AND source = 'P' AND productid = '$productId'";
			$sql = "SELECT recid, billingflag, invdate FROM productinvoice WHERE clientlocid = '$clientLocId' AND periodenddate = '$endingDate' AND type = 'I' AND source = 'P' AND productid = '$productId'";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my ($piRecId, $piBillingFlag, $invDate) = $sth->fetchrow_array();
			$sth->finish();

			if (($piBillingFlag eq "Y" || $piBillingFlag eq "P") && length($piRecId) > 0 && $piRecId > 0) {
				next;
			}

			if (length($piRecId) > 0 && $piRecId > 0) {
				$sql = $archObj->processSQL("UPDATE transactivitysc, specificproduct SET transactivitysc.closeddatevendinv = '". $runDate->getDate() ."', transactivitysc.archupdt = IF(transactivitysc.archupdt = 'P', 'U', transactivitysc.archupdt) WHERE transactivitysc.recid <= '$maxTaSCRecId' AND transactivitysc.locationid = '$clientLocId' AND transactivitysc.type IN ('BD', 'PF', 'DP', 'DF', 'SF', 'VF', 'VR', 'VC', 'DS', 'DP','CD','IP','IQ','IT','IB','IC','IG','IM','IA','IX','IF','IL','ID','IS','IY','PU','ST','IE') AND (transactivitysc.closeddatevendinv IS NULL OR transactivitysc.closeddatevendinv = '0000-00-00' OR transactivitysc.closeddatevendinv = '$invDate') AND specificproduct.recid = transactivitysc.specificproductid AND transactivitysc.datet <= '$endingDate' AND specificproduct.productid = '$productId' AND (transactivitysc.unitsalesvend IS NOT NULL AND transactivitysc.unitsalesvend > 0)");
			} else {
				$sql = $archObj->processSQL("UPDATE transactivitysc, specificproduct SET transactivitysc.closeddatevendinv = '". $runDate->getDate() ."', transactivitysc.archupdt = IF(transactivitysc.archupdt = 'P', 'U', transactivitysc.archupdt) WHERE transactivitysc.recid <= '$maxTaSCRecId' AND transactivitysc.locationid = '$clientLocId' AND transactivitysc.type IN ('BD', 'PF', 'DP', 'DF', 'SF', 'VF', 'VR', 'VC', 'DS', 'DP','CD','IP','IQ','IT','IB','IC','IG','IM','IA','IX','IF','IL','ID','IS','IY','PU','ST','IE') AND (transactivitysc.closeddatevendinv IS NULL OR transactivitysc.closeddatevendinv = '0000-00-00') AND specificproduct.recid = transactivitysc.specificproductid AND transactivitysc.datet <= '$endingDate' AND specificproduct.productid = '$productId' AND (transactivitysc.unitsalesvend IS NOT NULL AND transactivitysc.unitsalesvend > 0)");
			}
			print "$sql\n" if ($debug);
			my $rows = $dbh->do($sql) or die "$sql;\n";

			if ($rows > 0) {
				$sql = "SELECT charvar FROM locationsystem WHERE recid = 'INGRP' AND locationid = '$clientLocId' AND (endeffdt = '0000-00-00' OR endeffdt IS NULL OR endeffdt > '". $runDate->getDate() ."')";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my ($val_INGRP) = $sth->fetchrow_array();
				$sth->finish();

				if ($val_INGRP eq "Y") {
					$sql = "SELECT COUNT(*) FROM pubgroup WHERE publisherid = '$vendorLocId'";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my ($pubGroupCnt) = $sth->fetchrow_array();
					$sth->finish();

#					if ($pubGroupCnt > 1) {
#						$sql = "SELECT recid, sdesc FROM pubgroup WHERE publisherid = '$vendorLocId' ORDER BY recid";
#						print "$sql\n" if ($debug);
#						$sth = $dbh->prepare($sql);
#						$sth->execute() or die "$sql;\n";
#						my ($refPubGroups) = $sth->fetchall_arrayref();
#						$sth->finish();
#
#						foreach (@{$refPubGroups}) {
#							my ($pubGroupId, $pubGroupSDesc) = @{$_};
#						}
#					}
				} else {
					$sql = $archObj->processSQL("SELECT SUM(ta.actquantity * ta.unitsalesvend) as deamount FROM transactivitysc ta, specificproduct sp WHERE ta.recid <= '$maxTaSCRecId' AND ta.type IN ('BD', 'PF', 'DP', 'DF', 'SF', 'VF', 'VR', 'VC', 'DS', 'DP','CD','IP','IQ','IT','IB','IC','IG','IM','IA','IX','IF','IL','ID','IS','IY','PU','ST','IE') AND ta.closeddatevendinv = '". $runDate->getDate() ."' AND sp.recid = ta.specificproductid AND ta.datet <= '$endingDate' AND ta.locationid = '$clientLocId' AND sp.productid = '$productId' AND (ta.unitsalesvend IS NOT NULL AND ta.unitsalesvend > 0)");
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my $amount = ($sth->fetchrow_array())[0];
					$sth->finish();

					$amount = sprintf("$format",$amount);
					if ($amount > 0) {
						if (length($piRecId) > 0 && $piRecId > 0) {
							$sql = "UPDATE productinvoice SET totalamount = '$amount', invdate = '". $runDate->getDate() ."', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid = '$piRecId'";
							print "$sql\n" if ($debug);
							$dbh->do($sql) or die "$sql;\n";
						} else {
							$sql = "INSERT INTO productinvoice(clientlocid, customerlocid, productid, type, invdate, periodenddate, totalamount, billingflag, source) values('$clientLocId', '$vendorLocId', '$productId', 'I', '". $runDate->getDate() ."', '$endingDate', '$amount', 'N', 'P')";
							print "$sql\n" if ($debug);
							$dbh->do($sql) or die "$sql;\n";
							my $productInvoiceId = $dbh->{'mysql_insertid'};
						}

						$invoicedPDEndDate .= length($invoicedPDEndDate) == 0 ? $endingDate : "," . $endingDate;
					}
				}
			}
		}
	} # END OF WHILE LOOP
}

sub processSCVendPay {
	my ($clientId, $clientLocId) = @_;

	$sql = "SELECT DISTINCT(l.recid) FROM location l, locationlink ll, vendorlink vl WHERE vl.clientid = '$clientId' AND vl.locationid = ll.locationid AND l.recid = ll.locationid AND l.effdate < '". $runDate->getDate() ."'";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $refVendorLocIds = $sth->fetchall_arrayref();
	$sth->finish();

	my @vendorLocIds = @$refVendorLocIds;
	foreach my $record (@vendorLocIds) {

		print "\nInside Forloop\n" if ($debug);
		my $vendorLocId = $record->[0];
		print "$vendorLocId\n" if ($debug);

		if (length($vendorLocId) == 0) {
			$vendorLocId = 0;
		}

		# CHECKING THE VALID PUBLILCATIONS FOR THE SELECTED LOCATIONS IN THE PRODUCT TABLE
		$sql = "SELECT recid, scdaycodeid, basescdate, scperioddaycodeid, basescperioddate FROM product WHERE clientid = '$clientId' and vendorlocid = '$vendorLocId' /*AND producttype = 'PU'*/ AND (scdaycodeid IS NOT NULL AND scdaycodeid > 0) AND (scperioddaycodeid IS NOT NULL AND scperioddaycodeid > 0)";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my $refProuctIds = $sth->fetchall_arrayref();
		$sth->finish();

		my @products = @$refProuctIds;
		foreach my $record1 (@products) {

			my $productId = $record1->[0];
			my $billDaycodeId = $record1->[1];
			my $billBaseDate = $record1->[2];
			my $billPeriodDaycodeId = $record1->[3];
			my $billPeriodBaseDate = $record1->[4];

			# GETTING THE DAYCODE VALUES FOR PAYABLESDAYCODEID

			my $isPayablesDay = isLocationOpen($runDate->getDate(), $billDaycodeId, $billBaseDate, $billPeriodDaycodeId, $billPeriodBaseDate);

			if ($isPayablesDay == 0) {
				next ;
			}

			$sql = "SELECT type, period, sequence FROM daycode WHERE recid = $billDaycodeId";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my ($type, $period, $sequence) = $sth->fetchrow_array();
			$sth->finish();

			# WHEN TYPE IS "L" THEN CHANGE THE RUNDATE BACK TO THE RELATIVE DAYS FOR THE BILLINGDAYCODEID
			my $tempRunDate = '';
			if($type eq "L"){
				$tempRunDate = $runDate->getDate();
				# Finding the lagging period
				my $lag = $sequence * 7;
				$runDate->setDate($runDate->addDaysToDate($lag * -1));

			} # end of lagging period condition.

			# GETTING THE BILLINGPERIOD DAYCODE VALUES

#			my $endingDate = getEndingDate($period, $runDate->getDate(), $billPeriodDaycodeId, $billPeriodBaseDate);
			my $endingDate;
			if($val_MANAR > 0) {
				$sql = "SELECT periodenddate FROM ".$archObj->archDB.".productpayables WHERE clientlocid = '$clientLocId' AND vendorlocid = '$vendorLocId' AND type = 'I' AND source = 'P' ORDER BY periodenddate DESC LIMIT 1";
				$sth = $dbh->prepare($sql);
				$sth->execute() || die "$sql;\n";
				my ($latestPDEndDate) = $sth->fetchrow_array();
				$sth->finish();

				if(length($latestPDEndDate) == 0) {
					$endingDate = getEndingDate($period, $runDate->getDate(), $billPeriodDaycodeId, $billPeriodBaseDate);
				} else {
					$latestPDEndDate = cvt_general::DateOperation($latestPDEndDate, 1, "ADD");
					my $nextPDEndDate = getFutureEndDateFromStartDate($latestPDEndDate, $billPeriodDaycodeId, $billPeriodBaseDate);
					if($nextPDEndDate ge $runDate->getDate()) {
						$latestPDEndDate = cvt_general::DateOperation($latestPDEndDate, 1, "SUB");
						$endingDate = $latestPDEndDate;
					} else {
						$endingDate = $nextPDEndDate;
					}
				}
			} else {
				$endingDate = getEndingDate($period, $runDate->getDate(), $billPeriodDaycodeId, $billPeriodBaseDate);
				print "isPayablesDay:$isPayablesDay\nendingDate:$endingDate\n" if($debug);
				if ($isPayablesDay =~ /-/) {
					$endingDate = $isPayablesDay;
				}
			}

			print "ending_date:$endingDate\n" if ($debug);
			if (length($tempRunDate) > 0) {
				$runDate->setDate($tempRunDate);
				$tempRunDate = '';
			}

			if (length($endingDate) == 0) {
				#Billing date not found move to next product
				next ;
			}

			#CALCULATION OF EACH PUBLICATION FOR WHICH IS OPEN FOR PAYABLES.
			my $deAmount = 0;
			my $puAmount = 0;
			my $totalAmount = 0;

			$sql = $archObj->processSQL("SELECT COUNT(*) FROM transactivitysc ta, specificproduct sp WHERE ta.recid <= '$maxTaSCRecId' AND ta.type IN ('BD', 'PF', 'DP', 'SF', 'VF', 'VR', 'VC', 'DF', 'DS', 'PS','CD','IP','IQ','IT','IB','IC','IG','IM','IA','IX','IF','IL','ID','IS','IY','PU','ST','IE') AND ta.locationid = '$clientLocId' AND ta.customerlocid = '$vendorLocId' AND (ta.closeddatevend IS NULL OR ta.closeddatevend = '0000-00-00') AND sp.recid = ta.specificproductid AND ta.datet <= '$endingDate' AND sp.productid = '$productId'");
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my $isExists = ($sth->fetchrow_array())[0];
			$sth->finish();

			if ($isExists > 0) {

#				$sql = "SELECT recid, billingflag FROM productpayables WHERE clientlocid = '$clientLocId' AND vendorlocid = '$vendorLocId' AND payabledate = ". $runDate->getDate() ." AND periodenddate = '$endingDate' AND type = 'I' AND source = 'P' AND productid = '$productId'";
				$sql = "SELECT recid, billingflag, payabledate FROM productpayables WHERE clientlocid = '$clientLocId' AND vendorlocid = '$vendorLocId' AND periodenddate = '$endingDate' AND type = 'I' AND source = 'P' AND productid = '$productId'";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my ($productPayRecId, $productPayableBillingFlag, $invDate) = $sth->fetchrow_array();
				$sth->finish();

				if (($productPayableBillingFlag eq "Y" || $productPayableBillingFlag eq "P") && length($productPayRecId) > 0 && $productPayRecId > 0) {
					next;
				}

				if (length($productPayRecId) > 0 && $productPayRecId > 0) {
					$sql = $archObj->processSQL("UPDATE transactivitysc, specificproduct SET transactivitysc.closeddatevend = '". $runDate->getDate() ."', transactivitysc.archupdt = IF(transactivitysc.archupdt = 'P', 'U', transactivitysc.archupdt) WHERE transactivitysc.recid <= '$maxTaSCRecId' AND transactivitysc.type IN ('BD', 'PF', 'DP', 'SF', 'VF', 'VR', 'VC', 'DF', 'DS', 'PS','CD','IP','IQ','IT','IB','IC','IG','IM','IA','IX','IF','IL','ID','IS','IY','PU','ST','IE') AND transactivitysc.locationid = '$clientLocId' AND transactivitysc.customerlocid = '$vendorLocId' AND (transactivitysc.closeddatevend IS NULL OR transactivitysc.closeddatevend = '0000-00-00' OR transactivitysc.closeddatevend = '$invDate') AND specificproduct.recid = transactivitysc.specificproductid AND transactivitysc.datet <= '$endingDate' AND specificproduct.productid = '$productId'");
				} else {
					$sql = $archObj->processSQL("UPDATE transactivitysc, specificproduct SET transactivitysc.closeddatevend = '". $runDate->getDate() ."', transactivitysc.archupdt = IF(transactivitysc.archupdt = 'P', 'U', transactivitysc.archupdt) WHERE transactivitysc.recid <= '$maxTaSCRecId' AND transactivitysc.type IN ('BD', 'PF', 'DP', 'SF', 'VF', 'VR', 'VC', 'DF', 'DS', 'PS','CD','IP','IQ','IT','IB','IC','IG','IM','IA','IX','IF','IL','ID','IS','IY','PU','ST','IE') AND transactivitysc.locationid = '$clientLocId' AND transactivitysc.customerlocid = '$vendorLocId' AND (transactivitysc.closeddatevend IS NULL OR transactivitysc.closeddatevend = '0000-00-00') AND specificproduct.recid = transactivitysc.specificproductid AND transactivitysc.datet <= '$endingDate' AND specificproduct.productid = '$productId'");
				}
				print "$sql\n" if ($debug);
				my $row = $dbh->do($sql) or die "$sql;\n";

				if ($row > 0) {

					$sql = $archObj->processSQL("SELECT SUM(ta.actquantity * ta.unitcost) as desum FROM transactivitysc ta, specificproduct sp WHERE ta.recid <= '$maxTaSCRecId' AND sp.productid = '$productId' AND ta.locationid = '$clientLocId' AND ta.customerlocid = '$vendorLocId' AND ta.specificproductid = sp.recid AND ta.closeddatevend = '". $runDate->getDate() ."' AND ta.type IN ('BD', 'PF', 'DP', 'SF', 'VF', 'VR', 'VC', 'DF', 'DS', 'PS','CD','IP','IQ','IT','IB','IC','IG','IM','IA','IX','IF','IL','ID','IS','IY','PU','ST','IE')");
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my $amount = ($sth->fetchrow_array())[0];
					$sth->finish();

					$amount = sprintf("$format",$amount);
					if ($amount > 0) {

						$amount = $amount * -1;

						if (length($productPayRecId) > 0 && $productPayRecId > 0) {
							$sql = "UPDATE productpayables SET totalamount = '$amount', payabledate = '". $runDate->getDate() ."', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid = '$productPayRecId'";
							print "$sql\n" if ($debug);
							$dbh->do($sql) or die "$sql;\n";
						} else {
							# NOW INSERT A RECORD INTO THE PRODUCTPAYABLES FOR PAYING
							$sql = "INSERT INTO productpayables(clientlocid, vendorlocid, publicationid, type, payabledate, periodenddate, totalamount, billingflag, source) values('$clientLocId', '$vendorLocId', '$productId', 'I', '". $runDate->getDate() ."', '$endingDate', $amount, 'N', 'P')";
							print "$sql\n" if ($debug);
							$dbh->do($sql) or die "$sql;\n";
						}

						$invoicedPDEndDate .= length($invoicedPDEndDate) == 0 ? $endingDate : "," . $endingDate;
					}
				}
			} # END OF UPDATIONG THE TRANSACTIVITY RECORDS
		} # END OF PUBLICATION WHILE LOOP
	} # END OF LOCATIONWISE PUBLICATION
}
sub processPIACustomer{
	my ($clientId, $clientLocId) = @_;
	
	my $full_Path = "/usr/local/apache/htdocs/twce/cm/";
	my $scriptName = "piafunc.php";
	my $called_from = "SE024";
	my $_cutOffDate = "0000-00-00";
	my $_RunDate = $runDate->getDate();
	
	#Task#9196 Starts
	$sql = "SELECT /*se024*/ intvar FROM locationsystem WHERE recid = 'CDPIA' AND locationid = '$clientLocId' AND ( endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > '". $runDate->getDate() ."')";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $int_CDPIA = ($sth->fetchrow_array())[0];
	$sth->finish();
	if (length($int_CDPIA) == 0) {
		$int_CDPIA = 0;
	}
	my $cut_Off_Date = cvt_general::DateOperation($_RunDate, $int_CDPIA, "SUB");
	
	$sql = "SELECT /*se024*/ charvar FROM locationsystem WHERE locationid = '$clientLocId' AND recid = 'SUMTA' AND (endeffdt = '0000-00-00' OR endeffdt IS NULL OR endeffdt > now())";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my ($char_SUMTA) = $sth->fetchrow_array();
	$sth->finish();
	#Task#9196 Ends
	
	$sql = "SELECT DISTINCT(rl.locationid), rl.billingdaycodeid, rl.billingperioddaycodeid, rl.billingperiodbasedate, rl.piadaysadv, rl.dtlastpia, dc.period, l.effdate, l.endeffdate FROM routelink rl LEFT JOIN daycode dc on rl.billingperioddaycodeid = dc.recid, location l, locationlink ll, customerlink cl, company c WHERE cl.clientid = '$clientId' AND cl.clientlocid = '$clientLocId' AND cl.customerid = c.recid and ll.companyid = c.recid AND l.recid = ll.locationid AND l.effdate <= '". $runDate->getDate() ."' AND (ll.endeffdt = '0000-00-00' OR ll.endeffdt is null OR ll.endeffdt > '". $runDate->getDate() ."') AND rl.clientid = cl.clientid AND (rl.endeffdt = '0000-00-00' OR rl.endeffdt IS NULL OR rl.endeffdt > '". $runDate->getDate() ."') AND (rl.billingdaycodeid IS NOT NULL AND rl.billingdaycodeid > 0) AND (rl.billingperioddaycodeid IS NOT NULL AND rl.billingperioddaycodeid > 0) AND rl.piaflag = 'Y' AND rl.locationid = l.recid";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $refPIACustomers = $sth->fetchall_arrayref();
	$sth->finish();

	my @piaCustomers = @{$refPIACustomers};
	foreach my $record (@piaCustomers) {
		my ($customerId, $billDaycodeId, $billPeriodDaycodeId, $billPeriodBaseDate, $piaDaysAdv, $piaLastDate, $billPeriodDaycodePeriod, $_customerEffDt, $_customerEndeffdt) = @{$record};
		if (length (cvt_general::trim($_customerEndeffdt)) == 0) {
			$_customerEndeffdt = '0000-00-00';
		}
		if($debug){
			print "$customerId, $billDaycodeId, $billPeriodDaycodeId, $billPeriodBaseDate, $piaDaysAdv, $piaLastDate, $billPeriodDaycodePeriod, $_customerEffDt, $_customerEndeffdt\r\n";
		}
		
		if ($billPeriodDaycodePeriod eq "B" && ($billPeriodBaseDate eq '0000-00-00' || $billPeriodBaseDate eq '') ) {
			print "When BillingPeriod = 'B' BillingPeriodBaseDate must be set \n";
			cvt_general::error_log01("SE024","","","D059","2","0","$clientId","0","0","billingperiodbasedate Not Set for CustomerLocId:$customerId for billingperioddaycodeid = $billPeriodDaycodeId");
			next;			
		}
		
		my $prevPeriodEndDate = getEndingDate("DummyVar", $runDate->getDate(), $billPeriodDaycodeId, $billPeriodBaseDate);
		print "prevPeriodEndDate:$prevPeriodEndDate\n" if($debug);
		my $prev_period_start_date = cvt_general::DateOperation($prevPeriodEndDate, 1, "SUB");
		$prev_period_start_date = getEndingDate("DummyVar", $prev_period_start_date, $billPeriodDaycodeId, $billPeriodBaseDate);

		if ($prev_period_start_date < $_customerEffDt) {
			$prev_period_start_date = $_customerEffDt;
		}

		my $currPeriodStartDate =  cvt_general::DateOperation($prevPeriodEndDate, 1, "ADD");
		my $currPeriodEndDate = getFutureEndDateFromStartDate($currPeriodStartDate, $billPeriodDaycodeId, $billPeriodBaseDate);

		print "$currPeriodStartDate < $_customerEffDt\n" if($debug);
		if ($currPeriodStartDate lt $_customerEffDt) {
			$currPeriodStartDate = $_customerEffDt;
		}

		my $nextPeriodStartDate =  cvt_general::DateOperation($currPeriodEndDate, 1, "ADD");
		my $nextPeriodEndDate = getFutureEndDateFromStartDate($nextPeriodStartDate, $billPeriodDaycodeId, $billPeriodBaseDate);

		print "$customerId -> BillPeriodId:$billPeriodDaycodeId, \nPrevEnd:$prevPeriodEndDate, \nCurrStart:$currPeriodStartDate, CurrEnd:$currPeriodEndDate\n NextStart:$nextPeriodStartDate, NextEnd:$nextPeriodEndDate\n";
		
		print "sbz ---- prev_period_start_date = $prev_period_start_date\n" if($debug);
		print "sbz ---- prevPeriodEndDate:$prevPeriodEndDate\n" if($debug);
		print "sbz ---- currPeriodStartDate = $currPeriodStartDate\n" if($debug);
		print "sbz ---- currPeriodEndDate = $currPeriodEndDate\n" if($debug);
		print "sbz ---- nextPeriodStartDate = $nextPeriodStartDate\n" if($debug);
		print "sbz ---- nextPeriodEndDate = $nextPeriodEndDate\n" if($debug);

		my $fromDate = cvt_general::DateOperation($nextPeriodStartDate, $piaDaysAdv, "SUB");
		if($debug){
			print "fromDate: $fromDate\r\n";
		}

		$sql = "SELECT charvar FROM locationsystem WHERE recid = 'AUPIA' AND locationid = '$clientLocId'";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my $val_AUPIA = ($sth->fetchrow_array())[0];
		$sth->finish();
		
		if (length($piaLastDate) == 0) {
			if (length($billPeriodBaseDate) == 0  || $billPeriodBaseDate !~ /[1-9]/) {
				$sql = "SELECT COUNT(*) FROM productinvoice WHERE periodenddate = '$nextPeriodEndDate' AND type = 'D' AND source IN ('T', 'S') and clientlocid = '$clientLocId' AND customerlocid = '$customerId'";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my $duplicate = ($sth->fetchrow_array())[0];
				$sth->finish();

				if (!$duplicate) {
					print "sbz 11\n";
					print "cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerId $nextPeriodEndDate $billPeriodDaycodeId $_cutOffDate $_customerEffDt $_customerEndeffdt 0000-00-00 0000-00-00 0 0 $called_from D A $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \r\n" if (1);
				
					system("cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerId $nextPeriodEndDate $billPeriodDaycodeId $_cutOffDate $_customerEffDt $_customerEndeffdt 0000-00-00 0000-00-00 0 0 $called_from D A $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \&");
				}
				
			}
			else {
				$sql = "SELECT COUNT(*) FROM productinvoice WHERE periodenddate = '$currPeriodEndDate' AND type = 'D' AND source IN ('T', 'S') and clientlocid = '$clientLocId' AND customerlocid = '$customerId'";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my $duplicate = ($sth->fetchrow_array())[0];
				$sth->finish();
				
				if (!$duplicate) {
					print "sbz 12\n";
					#Task#9196 Starts
					#print "cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerId $currPeriodEndDate $billPeriodDaycodeId $_cutOffDate $_customerEffDt $_customerEndeffdt 0000-00-00 0000-00-00 0 0 $called_from D A $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \r\n" if (1);
				
					#system("cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerId $currPeriodEndDate $billPeriodDaycodeId $_cutOffDate $_customerEffDt $_customerEndeffdt 0000-00-00 0000-00-00 0 0 $called_from D A $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \&");
				}
				
			}
		}##end if (length($piaLastDate) == 0)
		else {
			print "FromDate:$fromDate , RunDate:" . $runDate->getDate() if ($debug);
			if ($fromDate eq $runDate->getDate()) {
				$sql = "SELECT COUNT(*) FROM productinvoice WHERE periodenddate = '$nextPeriodEndDate' AND type = 'D' AND source IN ('T', 'S') AND clientlocid = '$clientLocId' AND customerlocid = '$customerId'";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my $duplicate = ($sth->fetchrow_array())[0];
				
				$sth->finish();

				if (!$duplicate) {
					print "sbz 13\n";
					print "cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerId $nextPeriodEndDate $billPeriodDaycodeId $_cutOffDate $_customerEffDt $_customerEndeffdt 0000-00-00 $piaLastDate 0 0 $called_from D A $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \r\n" if (1);
				
					system("cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerId $nextPeriodEndDate $billPeriodDaycodeId $_cutOffDate $_customerEffDt $_customerEndeffdt 0000-00-00 $piaLastDate 0 0 $called_from D A $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \&");
				}
				
				
				# create credit balance only when new D record is created for PIA customer
				if ($val_AUPIA eq "Y") {
					print "sbz 14\n";
					#print "cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerId $currPeriodEndDate $billPeriodDaycodeId $_cutOffDate $_customerEffDt $_customerEndeffdt 0000-00-00 0000-00-00 1 0 $called_from D A $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \r\n" if (1);
				
					#system("cd $full_Path && php $scriptName cvt $clientId $clientLocId $customerId $currPeriodEndDate $billPeriodDaycodeId $_cutOffDate $_customerEffDt $_customerEndeffdt 0000-00-00 0000-00-00 1 0 $called_from D A $_RunDate $debug > /usr/local/twce/logs/cm/se024_pia.log 2 >> /usr/local/twce/logs/cm/se024_pia.err \&");
					
					##new logic point 1
					$sql = $archObj->processSQL("SELECT SUM(ta.actquantity * ta.unitsales) as desum FROM transactivity ta, specificproduct sp WHERE ta.locationid = '$clientLocId' AND ta.customerlocid = '$customerId' AND ta.type = 'DE' AND ta.specificproductid = sp.recid AND sp.datex >= '$currPeriodStartDate' AND sp.datex <= '$cut_Off_Date' ");
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my $deAmount = sprintf("$format",($sth->fetchrow_array())[0]);
					$sth->finish();
					print "deAmount:$deAmount\n" if ($debug);
					
					$sql = "SELECT /*SE024*/ invdate FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerId' AND type = 'D' AND invdate <= '$_RunDate' ORDER BY invdate DESC LIMIT 1";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my $pia_invdate = ($sth->fetchrow_array())[0];
					$sth->finish();
					
					$sql = "SELECT SUM(quantity * unitsales) as piaAmount FROM piaactivity WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerId' AND invdate = '$pia_invdate' AND datex >= '$currPeriodStartDate' AND datex <= '$cut_Off_Date'";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my $piaAmount = sprintf("$format",($sth->fetchrow_array())[0]);
					$sth->finish();
					print "piaAmount:$piaAmount\n" if ($debug);
					
					my $creditAmount = 0;
					$creditAmount = $piaAmount - $deAmount;
					print "creditAmount:$creditAmount\n" if ($debug);
					
					# allowed tolerance limit
					$sql = "SELECT realvar FROM locationsystem WHERE recid = 'PRODP' AND locationid = '$clientLocId'";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my $real_PRODP = ($sth->fetchrow_array())[0];
					$sth->finish();
					my $ntive_PRODP = -1 * $real_PRODP;
					
					print "$creditAmount <= $real_PRODP && $creditAmount >= $ntive_PRODP\n" if ($debug);
					if($creditAmount <= $real_PRODP && $creditAmount >= $ntive_PRODP) {
						next;
					}#END if ($creditAmount < $ntive_PRODP)
					
					my @dispNextPeriodEndDate = split(/-/, $nextPeriodEndDate);
					my $tempNextPeriodEndDate = sprintf("%02d/%02d/%02d", $dispNextPeriodEndDate[1], ,$dispNextPeriodEndDate[2], $dispNextPeriodEndDate[0] - 2000);
					
					my @dispCurrPeriodEndDate = split(/-/, $currPeriodEndDate);
					my $tempCurrPeriodEndDate = sprintf("%02d/%02d/%02d", $dispCurrPeriodEndDate[1], $dispCurrPeriodEndDate[2], $dispCurrPeriodEndDate[0] - 2000);
					
					my $new_creditAmount = $creditAmount*(-1);
					
					$sql = "SELECT billingflag FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerId' AND periodenddate = '$currPeriodEndDate' AND type = 'D' AND source = 'T'";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my $pi_billingflag = ($sth->fetchrow_array())[0];
					$sth->finish();
					
					$sql = "SELECT recid FROM productinvoice WHERE invdate = '". $runDate->getDate() ."' AND periodenddate = '$currPeriodEndDate' AND  type = 'C' AND source = 'T' AND clientlocid = '$clientLocId' AND customerlocid = '$customerId'";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my $duplicate = ($sth->fetchrow_array())[0];
					$sth->finish();
					
					if (length($duplicate) > 0) {
						$sql = "UPDATE productinvoice SET totalamount = '" . $new_creditAmount ."', archupdt = IF(archupdt = 'P', 'U', archupdt), comment = 'Transfer to Period Ending: $tempNextPeriodEndDate' , billingflag = '$pi_billingflag' WHERE recid = '$duplicate'";
						print "$sql\n" if ($debug);
						$dbh->do($sql) or die "$sql;\n";
					} else {
						$sql = "INSERT INTO productinvoice (clientlocid, customerlocid, type, source, invdate, periodenddate, totalamount, comment, billingflag) VALUES ('$clientLocId', '$customerId', 'C', 'T', '". $runDate->getDate() ."', '$currPeriodEndDate', '$new_creditAmount', 'Transfer to Period Ending: $tempNextPeriodEndDate', '$pi_billingflag')";
						print "$sql\n" if ($debug);
						$dbh->do($sql) or die "$sql;\n";
						my $productInvoiceId = $dbh->{'mysql_insertid'};
						if($productInvoiceId) {
							if($char_SUMTA eq 'Y') {
								cvt_general::insertInvoiceTaLinkProductInvoice($dbh, $clientId, $clientLocId, $customerId, '', 'T', 'C', $currPeriodEndDate, $runDate->getDate(), $productInvoiceId, 'SE024');
							}
						}
					}
					
					$sql = "SELECT billingflag FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerId' AND periodenddate = '$nextPeriodEndDate' AND type = 'D' AND source = 'T'";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my $pi_billingflag = ($sth->fetchrow_array())[0];
					$sth->finish();
					
					$sql = "SELECT recid FROM productinvoice WHERE invdate = '". $runDate->getDate() ."' AND periodenddate = '$nextPeriodEndDate' AND  type = 'C' AND source = 'T' AND clientlocid = '$clientLocId' AND customerlocid = '$customerId'";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my $duplicate = ($sth->fetchrow_array())[0];
					$sth->finish();
					if (length($duplicate) > 0) {
						$sql = "UPDATE productinvoice SET totalamount = '" . $creditAmount ."', archupdt = IF(archupdt = 'P', 'U', archupdt), comment = 'Transfer From Period Ending: $tempCurrPeriodEndDate', billingflag = '$pi_billingflag' WHERE recid = '$duplicate'";
						print "$sql\n" if ($debug);
						$dbh->do($sql) or die "$sql;\n";
					} else {
						# creating new credit record for next billing period
						$sql = "INSERT INTO productinvoice (clientlocid, customerlocid, type, source, invdate, periodenddate, totalamount, comment, billingflag) VALUES ('$clientLocId', '$customerId', 'C', 'T', '". $runDate->getDate() ."', '$nextPeriodEndDate', '$creditAmount', 'Transfer From Period Ending: $tempCurrPeriodEndDate', '$pi_billingflag')";
						print "$sql\n" if ($debug);
						$dbh->do($sql) or die "$sql;\n";
						my $productInvoiceId1 = $dbh->{'mysql_insertid'};
						if($productInvoiceId1) {
							if($char_SUMTA eq 'Y') {
								cvt_general::insertInvoiceTaLinkProductInvoice($dbh, $clientId, $clientLocId, $customerId, '', 'T', 'C', $nextPeriodEndDate, $runDate->getDate(), $productInvoiceId1, 'SE024');
							}
						}
					}
					system("perl se/cm/tra50_archdata.pl $clientId FORCECOPY");
					#Task#9196 Ends
				}##End if ($val_AUPIA eq "Y")
			}##End if ($fromDate le $runDate->getDate())
		}
	}
}
sub processPIACustomer_Old {
	my ($clientId, $clientLocId) = @_;

	$sql = "SELECT DISTINCT(rl.locationid), rl.billingdaycodeid, rl.billingperioddaycodeid, rl.billingperiodbasedate, rl.piadaysadv, rl.dtlastpia, dc.period FROM routelink rl LEFT JOIN daycode dc on rl.billingperioddaycodeid = dc.recid, location l, locationlink ll, customerlink cl, company c WHERE cl.clientid = '$clientId' AND cl.clientlocid = '$clientLocId' AND cl.customerid = c.recid and ll.companyid = c.recid AND l.recid = ll.locationid AND l.effdate < '". $runDate->getDate() ."' AND (ll.endeffdt = '0000-00-00' OR ll.endeffdt is null OR ll.endeffdt > '". $runDate->getDate() ."') AND rl.clientid = cl.clientid AND (rl.endeffdt = '0000-00-00' OR rl.endeffdt IS NULL OR rl.endeffdt > '". $runDate->getDate() ."') AND (rl.billingdaycodeid IS NOT NULL AND rl.billingdaycodeid > 0) AND (rl.billingperioddaycodeid IS NOT NULL AND rl.billingperioddaycodeid > 0) AND rl.piaflag = 'Y' AND rl.locationid = l.recid";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $refPIACustomers = $sth->fetchall_arrayref();
	$sth->finish();

	my @piaCustomers = @{$refPIACustomers};
	foreach my $record (@piaCustomers) {
		my ($customerId, $billDaycodeId, $billPeriodDaycodeId, $billPeriodBaseDate, $piaDaysAdv, $piaLastDate, $billPeriodDaycodePeriod) = @{$record};

		$sql = "SELECT effdate FROM location WHERE recid = '$customerId'";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my $customerEffDt = ($sth->fetchrow_array())[0];
		$sth->finish();
	
		if ($billPeriodDaycodePeriod eq "B" && ($billPeriodBaseDate eq '0000-00-00' || $billPeriodBaseDate eq '') ) {
			print "When BillingPeriod = 'B' BillingPeriodBaseDate must be set \n";
			cvt_general::error_log01("SE024","","","D059","2","0","$clientId","0","0","billingperiodbasedate Not Set for CustomerLocId:$customerId for billingperioddaycodeid = $billPeriodDaycodeId");
			next;			
		}
		
		my $prevPeriodEndDate = getEndingDate("DummyVar", $runDate->getDate(), $billPeriodDaycodeId, $billPeriodBaseDate);
		print "prevPeriodEndDate:$prevPeriodEndDate\n" if($debug);
		my $prev_period_start_date = cvt_general::DateOperation($prevPeriodEndDate, 1, "SUB");
		$prev_period_start_date = getEndingDate("DummyVar", $prev_period_start_date, $billPeriodDaycodeId, $billPeriodBaseDate);

		if ($prev_period_start_date < $customerEffDt) {
			$prev_period_start_date = $customerEffDt;
		}

		my $currPeriodStartDate =  cvt_general::DateOperation($prevPeriodEndDate, 1, "ADD");
		my $currPeriodEndDate = getFutureEndDateFromStartDate($currPeriodStartDate, $billPeriodDaycodeId, $billPeriodBaseDate);

		print "$currPeriodStartDate < $customerEffDt\n" if($debug);
		if ($currPeriodStartDate lt $customerEffDt) {
			$currPeriodStartDate = $customerEffDt;
		}

		my $nextPeriodStartDate =  cvt_general::DateOperation($currPeriodEndDate, 1, "ADD");
		my $nextPeriodEndDate = getFutureEndDateFromStartDate($nextPeriodStartDate, $billPeriodDaycodeId, $billPeriodBaseDate);

		print "$customerId -> BillPeriodId:$billPeriodDaycodeId, \nPrevEnd:$prevPeriodEndDate, \nCurrStart:$currPeriodStartDate, CurrEnd:$currPeriodEndDate\n NextStart:$nextPeriodStartDate, NextEnd:$nextPeriodEndDate\n";

		my $fromDate = cvt_general::DateOperation($nextPeriodStartDate, $piaDaysAdv, "SUB");

		$sql = "SELECT charvar FROM locationsystem WHERE recid = 'AUPIA' AND locationid = '$clientLocId'";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my $val_AUPIA = ($sth->fetchrow_array())[0];
		$sth->finish();

		if (length($piaLastDate) == 0) {

			#Need to create D record
			if (length($billPeriodBaseDate) == 0  || $billPeriodBaseDate !~ /[1-9]/) {
				$sql = "SELECT COUNT(*) FROM productinvoice WHERE periodenddate = '$nextPeriodEndDate' AND type = 'D' AND source = 'T' and clientlocid = '$clientLocId' AND customerlocid = '$customerId'";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my $duplicate = ($sth->fetchrow_array())[0];
				$sth->finish();

				if (!$duplicate) {
					my $periodEndDate;
					$sql = "SELECT periodenddate FROM productinvoice WHERE type = 'I' AND clientlocid = '$clientLocId' AND customerlocid = '$customerId' ORDER BY periodenddate DESC LIMIT 1";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					if ($sth->rows > 0) {
						$periodEndDate = ($sth->fetchrow_array())[0];
					}
					$sth->finish();

					if ($periodEndDate gt $nextPeriodStartDate) {
						$nextPeriodStartDate = cvt_general::DateOperation($periodEndDate, 1, "ADD");
					}

					# Total return will be Wholeseler and Distributor data both format will be
					# ClientLocId##TotalAmount##Comment||ClientLocId##TotalAmount##Comment||ClientLocId##TotalAmount##Comment
					my $commentStr = countTotalAmount($nextPeriodStartDate, $nextPeriodEndDate, $customerId, $clientId, $clientLocId, 0);
					print "commentStr:$commentStr\n" if ($debug);
					my @piaTotalData = split(/\|\|/, $commentStr);
					print "@piaTotalData" . "\n" if ($debug);
					foreach my $piaTotalDataRec (@piaTotalData) {
						if (length($piaTotalDataRec) > 0) {
							my ($tempClientLocId, $totalAmount, $locCommentStr) = split(/##/, $piaTotalDataRec);
							$locCommentStr = $dbh->quote($locCommentStr);
							$sql = "INSERT INTO productinvoice(clientlocid, customerlocid, type, source, invdate, periodenddate, totalamount, billingflag) VALUES ('$tempClientLocId', '$customerId', 'D', 'T', '". $runDate->getDate() ."', '$nextPeriodEndDate', '$totalAmount', 'N')";
							print "$sql\n" if ($debug);
							$dbh->do($sql) or die "$sql;\n";
							my $prodInvId = $dbh->{'mysql_insertid'};
							my $xRunDate = $runDate->getDate();
							#system("perl se/cm/pia1_archdata.pl $tempClientLocId $customerId $nextPeriodEndDate $prodInvId $xRunDate");
							
						}
					}
#					my ($totalAmount, $comment) = split(/=/, $commentStr);

					$sql = "UPDATE routelink SET dtlastpia = '$nextPeriodEndDate' WHERE clientid = '$clientId' AND locationid = '$customerId'";
					print "$sql\n" if ($debug);
					$dbh->do($sql) or die "$sql;\n";
				}
			} else {
				$sql = "SELECT COUNT(*) FROM productinvoice WHERE periodenddate = '$currPeriodEndDate' AND type = 'D' AND source = 'T' and clientlocid = '$clientLocId' AND customerlocid = '$customerId'";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my $duplicate = ($sth->fetchrow_array())[0];
				$sth->finish();

				if (!$duplicate) {
					my $periodEndDate;
					$sql = "SELECT periodenddate FROM productinvoice WHERE type = 'I' AND clientlocid = '$clientLocId' AND customerlocid = '$customerId' ORDER BY periodenddate DESC LIMIT 1";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					if ($sth->rows > 0) {
						$periodEndDate = ($sth->fetchrow_array())[0];
					}
					$sth->finish();

					if ($periodEndDate gt $currPeriodStartDate) {
						$currPeriodStartDate = cvt_general::DateOperation($periodEndDate, 1, "ADD");
					}

					my $commentStr = countTotalAmount($currPeriodStartDate, $currPeriodEndDate, $customerId, $clientId, $clientLocId, 0);

					my @piaTotalData = split(/\|\|/, $commentStr);
					foreach my $piaTotalDataRec (@piaTotalData) {
						if (length($piaTotalDataRec) > 0) {
							my ($tempClientLocId, $totalAmount, $locCommentStr) = split(/##/, $piaTotalDataRec);
							$locCommentStr = $dbh->quote($locCommentStr);
							$sql = "INSERT INTO productinvoice(clientlocid, customerlocid, type, source, invdate, periodenddate, totalamount, billingflag) VALUES ('$tempClientLocId', '$customerId', 'D', 'T', '". $runDate->getDate() ."', '$nextPeriodEndDate', '$totalAmount', 'N')";
							print "$sql\n" if ($debug);
							$dbh->do($sql) or die "$sql;\n";
							my $prodInvId = $dbh->{'mysql_insertid'};
							my $xRunDate = $runDate->getDate();
							#system("perl se/cm/pia1_archdata.pl $tempClientLocId $customerId $nextPeriodEndDate $prodInvId $xRunDate");							
						}
					}
#					my ($totalAmount, $comment) = split(/=/, $commentStr);

					$sql = "UPDATE routelink SET dtlastpia = '$nextPeriodEndDate' WHERE clientid = '$clientId' AND locationid = '$customerId'";
					print "$sql\n" if ($debug);
					$dbh->do($sql) or die "$sql;\n";
#					my ($totalAmount, $comment) = split(/=/, $commentStr);
#
#
#					$sql = "INSERT INTO productinvoice (clientlocid, customerlocid, type, source, invdate, periodenddate, totalamount, billingflag, comment) VALUES ('$clientLocId', '$customerId', 'D', 'T', '". $runDate->getDate() ."', '$currPeriodEndDate', '$totalAmount', 'N', '$comment')";
#					print "$sql\n" if ($debug);
#					$dbh->do($sql) or die "$sql;\n";

					$sql = "UPDATE routelink SET dtlastpia = '$currPeriodEndDate' WHERE clientid = '$clientId' AND locationid = '$customerId'";
					print "$sql\n" if ($debug);
					$dbh->do($sql) or die "$sql;\n";
				}
			}
		} else {
			print "FromDate:$fromDate , RunDate:" . $runDate->getDate() if ($debug);
			if ($fromDate le $runDate->getDate()) {

				$sql = "SELECT COUNT(*) FROM productinvoice WHERE periodenddate = '$nextPeriodEndDate' AND type = 'D' AND source = 'T' AND clientlocid = '$clientLocId' AND customerlocid = '$customerId'";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my $duplicate = ($sth->fetchrow_array())[0];
				$sth->finish();

				if (!$duplicate) {


					my $commentStr = countTotalAmount($nextPeriodStartDate, $nextPeriodEndDate, $customerId, $clientId, $clientLocId, 0);
					print "commentStr: $commentStr\n" if ($debug);
					my @piaTotalData = split(/\|\|/, $commentStr);
					print "@piaTotalData" . "\n" if ($debug);
					foreach my $piaTotalDataRec (@piaTotalData) {
						if (length($piaTotalDataRec) > 0) {
							my ($tempClientLocId, $totalAmount, $locCommentStr) = split(/##/, $piaTotalDataRec);
							print "piaTotalDataRec: piaTotalDataRec\n" if ($debug);
							print "($tempClientLocId, $totalAmount, $locCommentStr)\n" if ($debug);
							$locCommentStr = $dbh->quote($locCommentStr);
							$sql = "INSERT INTO productinvoice(clientlocid, customerlocid, type, source, invdate, periodenddate, totalamount, billingflag) VALUES ('$tempClientLocId', '$customerId', 'D', 'T', '". $runDate->getDate() ."', '$nextPeriodEndDate', '$totalAmount', 'N')";
							print "$sql\n" if ($debug);
							$dbh->do($sql) or die "$sql;\n";
							my $prodInvId = $dbh->{'mysql_insertid'};
							my $xRunDate = $runDate->getDate();
							#system("perl se/cm/pia1_archdata.pl $tempClientLocId $customerId $nextPeriodEndDate $prodInvId $xRunDate");
						}
					}
#					my ($totalAmount, $comment) = split(/=/, $commentStr);

					$sql = "UPDATE routelink SET dtlastpia = '$nextPeriodEndDate' WHERE clientid = '$clientId' AND locationid = '$customerId'";
					print "$sql\n" if ($debug);
					$dbh->do($sql) or die "$sql;\n";
#					my ($totalAmount, $comment) = split(/=/, $commentStr);
#
#					$sql = "INSERT INTO productinvoice(clientlocid, customerlocid, type, source, invdate, periodenddate, totalamount, billingflag, comment) VALUES ('$clientLocId', '$customerId', 'D', 'T', '". $runDate->getDate() ."', '$nextPeriodEndDate', '$totalAmount', 'N', '$comment')";
#					print "$sql\n" if ($debug);
#					$dbh->do($sql) or die "$sql;\n";

					$sql = "UPDATE routelink SET dtlastpia = '$nextPeriodEndDate' WHERE clientid = '$clientId' AND locationid = '$customerId'";
					print "$sql\n" if ($debug);
					$dbh->do($sql) or die "$sql;\n";

					# create credit balance only when new D record is created for PIA customer
					if ($val_AUPIA eq "Y") {

						# for details look into Applications/application_concept/pia.htm file in AUPIA section.

						#finding the start date of the current period
						my $periodEndDate;
						$sql = "SELECT periodenddate FROM ".$archObj->archDB.".productinvoice WHERE type = 'I' AND clientlocid = '$clientLocId' AND customerlocid = '$customerId' ORDER BY periodenddate DESC LIMIT 1";
						print "$sql\n" if ($debug);
						$sth = $dbh->prepare($sql);
						$sth->execute() or die "$sql;\n";
						if ($sth->rows > 0) {
							$periodEndDate = ($sth->fetchrow_array())[0];
						}
						$sth->finish();

						if ($periodEndDate gt $currPeriodStartDate) {
							$currPeriodStartDate = cvt_general::DateOperation($periodEndDate, 1, "ADD");
						}

						#finding the sum of paid + credit amount for the current period
						$sql = "SELECT SUM(totalamount) FROM ".$archObj->archDB.".productinvoice WHERE periodenddate = '$currPeriodEndDate' AND type IN ('P', 'C') AND clientlocid = '$clientLocId' AND customerlocid = '$customerId'";
						print "$sql\n" if ($debug);
						$sth = $dbh->prepare($sql);
						$sth->execute() or die "$sql;\n";
						my $currPIAPaidAmount = ($sth->fetchrow_array())[0];
						$sth->finish();

						if (length($currPIAPaidAmount) == 0) {
							# no paid or credit amount so no amount to transfer and hence moving to next location
							next;
						}

						$sql = "SELECT intvar FROM locationsystem WHERE recid = 'CDPIA' AND locationid = '$clientLocId'";
						print "$sql\n" if ($debug);
						$sth = $dbh->prepare($sql);
						$sth->execute() or die "$sql;\n";
						my $intvar_CDPIA = ($sth->fetchrow_array())[0];
						$sth->finish();

						my $cutOffDate = cvt_general::DateOperation($runDate->getDate(), $intvar_CDPIA, "SUB");

						#if cutoff date is in the range of current period then proceed ahead.
						if (cvt_general::DateDiff($cutOffDate, $currPeriodStartDate) >= 0) {

							# finding the products delivered at that location
							my $productIds = "";
							$sql = "SELECT DISTINCT(sd.productid) FROM standarddraw sd, product p WHERE sd.customerlocid = '$customerId' AND sd.clientlocid = '$clientLocId' AND sd.effdt <= '$currPeriodEndDate' AND (sd.endeffdt IS NULL OR sd.endeffdt = '0000-00-00' OR sd.endeffdt > '$currPeriodStartDate') AND p.recid = sd.productid /*AND p.producttype = 'PU'*/ AND (p.endeffdt IS NULL OR p.endeffdt = '0000-00-00' OR p.endeffdt > '$currPeriodStartDate')";
							print "$sql\n" if ($debug);
							$sth = $dbh->prepare($sql);
							$sth->execute() or die "$sql;\n";
							while (my $row = ($sth->fetchrow_array())[0]) {
								if ($productIds eq "") {
									$productIds = $row;
								} else {
									$productIds .= "," . $row;
								}
							}
							$sth->finish();

							$productIds =~ s/^,//;

							# finding the total actual amount from start to cutoff date

							my $specificProductIds = "";
							my $currActAmount = 0;

							if (length($productIds) > 0) {

								$sql = "SELECT DISTINCT(recid) FROM ".$archObj->archDB.".specificproduct WHERE datex <= '$cutOffDate' AND datex >=  '$currPeriodStartDate' AND productid IN ($productIds) AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt < '$cutOffDate')";
								print "$sql\n" if ($debug);
								$sth = $dbh->prepare($sql);
								$sth->execute() or die "$sql;\n";
								while (my $row = ($sth->fetchrow_array())[0]) {
									if ($specificProductIds eq "") {
										$specificProductIds = $row;
									} else {
										$specificProductIds .= "," . $row;
									}
								}
								$sth->finish();
								$specificProductIds =~ s/^,//;
							}

							if (length($specificProductIds) > 0) {
								# DE + AD amount
								$sql = $archObj->processSQL("SELECT SUM(actquantity * unitsales) as desum FROM transactivity WHERE type IN ('DE', 'AD') AND (closeddatecust IS NULL OR closeddatecust = '0000-00-00') AND specificproductid IN ($specificProductIds) AND customerlocid = '$customerId' AND locationid = '$clientLocId'");
								print "$sql\n" if ($debug);
								$sth = $dbh->prepare($sql);
								$sth->execute() or die "$sql;\n";
								my $deAmount = sprintf("$format",($sth->fetchrow_array())[0]);
								$sth->finish();

								# PU amount
								$sql = $archObj->processSQL("SELECT SUM(actquantity * unitsales) as desum FROM transactivity WHERE type = 'PU' AND (closeddatecust IS NULL OR closeddatecust = '0000-00-00') AND specificproductid IN ($specificProductIds) AND customerlocid = '$customerId' AND locationid = '$clientLocId'");
								print "$sql\n" if ($debug);
								$sth = $dbh->prepare($sql);
								$sth->execute() or die "$sql;\n";
								my $puAmount = sprintf("$format",($sth->fetchrow_array())[0]);
								$sth->finish();

								$currActAmount = $deAmount - $puAmount;
								$currActAmount = sprintf("$format",$currActAmount);
							}

							print "currActAmount:$currActAmount\n" if ($debug);

							# finding the new total amount for current period for whole period
							my $commentStr = countTotalAmount($currPeriodStartDate, $cutOffDate,  $customerId, $clientId, $clientLocId, 1);
							my ($currCutOffPIAAmount, $comment) = split(/=/, $commentStr);

							print "currCutOffPIAAmount:$currCutOffPIAAmount,  comment:$comment\n" if ($debug);

							if ($currActAmount < $currCutOffPIAAmount) {

								# finding the new total amount for current period for whole period
								my $commentStr = countTotalAmount($currPeriodStartDate, $currPeriodEndDate,  $customerId, $clientId, $clientLocId, 1);

								my ($currNewPIAAmount, $comment) = split(/=/, $commentStr);
								print "currNewPIAAmount:$currNewPIAAmount, comment:$comment\n" if ($debug);

								my $revisedAmount = $currNewPIAAmount - ($currCutOffPIAAmount - $currActAmount);
								my $creditAmount = $revisedAmount - abs($currPIAPaidAmount);

								print "currPIAPaidAmount:$currPIAPaidAmount\n" if ($debug);
								print "revisedAmount:$revisedAmount\n" if ($debug);
								print "creditAmount:$creditAmount\n" if ($debug);

								# allowed tolerance limit
								$sql = "SELECT realvar FROM locationsystem WHERE recid = 'PRODP' AND locationid = '$clientLocId'";
								print "$sql\n" if ($debug);
								$sth = $dbh->prepare($sql);
								$sth->execute() or die "$sql;\n";
								my $real_PRODP = ($sth->fetchrow_array())[0];
								$sth->finish();
								my $ntive_PRODP = -1 * $real_PRODP;

								if ($creditAmount < $ntive_PRODP) {

									# Finding the current period's advance invoice record
									$sql = "SELECT recid FROM productinvoice WHERE invdate = '". $runDate->getDate() ."' AND periodenddate = '$currPeriodEndDate' AND  type = 'C' AND source = 'T' AND clientlocid = '$clientLocId' AND customerlocid = '$customerId'";
									print "$sql\n" if ($debug);
									$sth = $dbh->prepare($sql);
									$sth->execute() or die "$sql;\n";
									my $duplicate = ($sth->fetchrow_array())[0];
									$sth->finish();


									my @dispNextPeriodEndDate = split(/-/, $nextPeriodEndDate);
									my $tempNextPeriodEndDate = sprintf("%02d/%02d/%02d", $dispNextPeriodEndDate[1], ,$dispNextPeriodEndDate[2], $dispNextPeriodEndDate[0] - 2000);
									if (length($duplicate) > 0) {
										$sql = "UPDATE productinvoice SET totalamount = '" . abs($creditAmount) ."', archupdt = IF(archupdt = 'P', 'U', archupdt), comment = 'Transfer to Period Ending: $tempNextPeriodEndDate' , billingflag = 'Y' WHERE recid = '$duplicate'";
										print "$sql\n" if ($debug);
										$dbh->do($sql) or die "$sql;\n";
									} else {
										$sql = "INSERT INTO productinvoice (clientlocid, customerlocid, type, source, invdate, periodenddate, totalamount, comment, billingflag) VALUES ('$clientLocId', '$customerId', 'C', 'T', '". $runDate->getDate() ."', '$currPeriodEndDate', '" . abs($creditAmount) ."', 'Transfer to Period Ending: $tempNextPeriodEndDate', 'Y')";
										print "$sql\n" if ($debug);
										$dbh->do($sql) or die "$sql;\n";
									}

									# creating new credit record for next billing period
									$duplicate = "";
									$sql = "SELECT recid FROM productinvoice WHERE invdate = '". $runDate->getDate() ."' AND periodenddate = '$nextPeriodEndDate' AND type = 'C' AND source = 'T' AND clientlocid = '$clientLocId' AND customerlocid = '$customerId'";
									print "$sql\n" if ($debug);
									$sth = $dbh->prepare($sql);
									$sth->execute() or die "$sql;\n";
									$duplicate = ($sth->fetchrow_array())[0];
									$sth->finish();

									my @dispCurrPeriodEndDate = split(/-/, $currPeriodEndDate);
									my $tempCurrPeriodEndDate = sprintf("%02d/%02d/%02d", $dispCurrPeriodEndDate[1], $dispCurrPeriodEndDate[2], $dispCurrPeriodEndDate[0] - 2000);
									if (length($duplicate) > 0) {
										$sql = "UPDATE productinvoice SET totalamount = '$creditAmount', archupdt = IF(archupdt = 'P', 'U', archupdt), comment = 'Transfer From Period Ending: $tempCurrPeriodEndDate', billingflag = 'Y'  WHERE recid = '$duplicate'";
										print "$sql\n" if ($debug);
										$dbh->do($sql) or die "$sql;\n";
									} else {
										$sql = "INSERT INTO productinvoice (clientlocid, customerlocid, type, source, invdate, periodenddate, totalamount, comment, billingflag) VALUES ('$clientLocId', '$customerId', 'C', 'T', '". $runDate->getDate() ."', '$nextPeriodEndDate', '$creditAmount', 'Transfer From Period Ending: $tempCurrPeriodEndDate', 'Y')";
										print "$sql\n" if ($debug);
										$dbh->do($sql) or die "$sql;\n";
									}
								}
							}
						}
					}
				}
			}
		}
	}
}


sub lastDateOfMonth {
	my $dt = $_[0];
	if (length($dt) == 0) {
		return;
	}
	my ($yyyy, $mm, $dd) = ($dt =~ /(\d+)[^a-zA-Z+](\d+)[^a-zA-Z+](\d+)/);
	$dd = cvt_general::DaysOfMonth($dt);
	$dt = sprintf("%04d-%02d-%02d", $yyyy, $mm, $dd);
	return $dt;
}

sub updateVendingLocs {
	print "==============updateVendingLocs=================\n" if ($debug);
	my ($clientLocId, $customerLocId, $endingDate) = @_;

	# CHECKING OF LOCATION
	# IS THE LOCATION IS VENDING LOCATION OR NOT
	$sql = "SELECT COUNT(*) AS cnt FROM vendinglocationlink WHERE locationid = '$customerLocId'";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $count = ($sth->fetchrow_array())[0];
	$sth->finish();

	if ($count == 0) {
		return ;
	}

	# IF LOCATION IS VENDING LOCATION THEN CALCULATE
	# THE UNCOLLECTED AMOUNT FOR THE LOCATION

	# CALCULATE THE DE AMOUNT
	$sql = $archObj->processSQL("SELECT SUM(ROUND(ta.actquantity * ta.unitsales, $val_DTRAD)) as desum FROM transactivity ta, specificproduct sp WHERE ta.recid <= '$maxTaRecId' AND ta.locationid = '$clientLocId' AND ta.customerlocid = '$customerLocId' AND (ta.closeddatecust IS NULL OR ta.closeddatecust = '0000-00-00') AND sp.recid = ta.specificproductid and sp.datex <= '$endingDate' AND (ta.type = 'DE' OR ta.type = 'AD')");
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $deAmount = ($sth->fetchrow_array())[0];
	$sth->finish();

	$deAmount = sprintf("$format",$deAmount);

	# CALCULATE THE PU AMOUNT
	$sql = $archObj->processSQL("SELECT SUM(ROUND(ta.actquantity * ta.unitsales, $val_DTRAD)) as pusum FROM transactivity ta, specificproduct sp WHERE ta.recid <= '$maxTaRecId' AND ta.locationid = '$clientLocId' AND ta.customerlocid = '$customerLocId' AND (ta.closeddatecust IS NULL OR ta.closeddatecust = '0000-00-00') AND sp.recid = ta.specificproductid and sp.datex <= '$endingDate' AND ta.type = 'PU'");
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $puAmount = ($sth->fetchrow_array())[0];
	$sth->finish();

	$puAmount = sprintf("$format",$puAmount);

	my $uncollected = $deAmount - $puAmount;
	$uncollected = sprintf("$format",$uncollected);

	$sql = "UPDATE vendinglocationlink SET uncollected = '$uncollected' WHERE locationid = '$customerLocId'";
	print "$sql\n" if ($debug);
	$dbh->do($sql) or die "$sql;\n";

} # END OF UPDATEVENDINGLOCS FUNCTION




sub calculateEndDate {
	my $runDate = new date( shift );
	my ($day, $runDateDOW) = @_;

	my @dcDays = $day =~ /[A-Z]{3}/g;
	foreach  (@dcDays) {
		$_ = cvt_general::GetDOW($_);
	}
	@dcDays = sort @dcDays;

	my $previousDOW = $runDateDOW;
	my $endingDate = '';
	my $flag = 0;

	foreach my $value (@dcDays) {
		if($runDateDOW > $value){
			$previousDOW = $value;
			$flag = 1;
		} elsif($runDateDOW < $value) {
			if ($flag) {
				last;
			}
			$previousDOW = $value;
		}
	}

	if($runDateDOW > $previousDOW){
		$endingDate = $runDateDOW - $previousDOW;
	} else {
		$endingDate = 7 - $previousDOW + $runDateDOW;
	}

	$endingDate = cvt_general::DateOperation($runDate->getDate(), $endingDate, "SUB");

	return $endingDate;

}



sub isLocationOpen {
	#rundate, schedule daycode, schedule basedate, periodend daycode, periodend basedate
	print "\n\n --------------------------Is Location Open Call---------------------------------\n\n";

	my $runDate = new date(shift);
	my ($daycodeId, $baseDate, $periodDaycodeId, $periodBaseDate) = @_;
	#daycode is available. Finding required values from record
	
	#$runDate = '2015-03-01';
	$sql = "SELECT type, day , period, sequence FROM daycode WHERE recid = '$daycodeId'";
	print "\n$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my ($daycodeType, $daycodeDay, $daycodePeriod, $daycodeSequence) = $sth->fetchrow_array();
	$sth->finish();

	print "\nDayCodeData:$daycodeType, $daycodeDay, $daycodePeriod, $daycodeSequence\n\n";
	
	my $tempdaycodeSequence = 0;
		if($daycodeSequence < 0)
		{
			$tempdaycodeSequence = $daycodeSequence;
			my $MinusendingDate = new date($runDate->getDate());
			 #$MinusendingDate = $MinusendingDate->setDate($runDate->getDate());
			print "\n\n MinusendingDate = RunDate: ".$MinusendingDate->getDate();
			 $MinusendingDate->setDate(getEndingDate($daycodePeriod, $MinusendingDate->getDate(), $periodDaycodeId, $periodBaseDate));
			print "\n\n MinusendingDate = GetEndDate: ".$MinusendingDate->getDate();			
			 $MinusendingDate->setDate($MinusendingDate->addDaysToDate(($daycodeSequence)));
			print "\n\n MinusendingDate = Add DaySquuence: ".$MinusendingDate->getDate();
			 $daycodeSequence = $MinusendingDate->getDayOfWeek();
			 print "\n\n MinusendingDate = daycodeSequence: $daycodeSequence---->".$MinusendingDate->getDate();
			
			
		}
	
	
	$sql = "SELECT type, day , period, sequence FROM daycode WHERE recid = '$periodDaycodeId'";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my ($periodDaycodeType, $periodDaycodeDay, $periodDaycodePeriod, $periodDaycodeSequence) = $sth->fetchrow_array();
	$sth->finish();

	print "\n\n PeriodDayCodeData:$periodDaycodeType, $periodDaycodeDay, $periodDaycodePeriod, $periodDaycodeSequence \n \n ";
	
	
	if ($val_MANAR > 0 || $val_MANCR > 0 ) {
		if ($daycodePeriod eq "O") {
			return 1;
		}
		else {
			return 0;
		}
	}

	my $DOW = $runDate->getDayOfWeek();
	my $dowStr = $runDate->getTextFromDOW();

	my $flag = 0;

	if($periodDaycodePeriod eq "I" || $periodDaycodePeriod eq "T") {
		print "HERE\n";
		if($periodDaycodePeriod eq "I") {
			my $endingDate = $runDate->addDaysToDate(-1);
			my $flag = $endingDate;
			return $flag;
		}
		elsif($periodDaycodePeriod eq "T"){
			my $endingDate = $runDate->getDate();
			my $flag = $endingDate;
			return $flag;
		}
		
	}
	
	if ($daycodePeriod eq "D" && $daycodeType eq "W") {

		# finding periodenddate first.
		my ($cnt, $cnt1) = 0;

		my $openDate = $runDate->getDate();
		my $endingDate = $runDate->getDate();
		# if ($periodDaycodePeriod eq "J" || $periodDaycodePeriod eq "K" || $periodDaycodePeriod eq "L" ) {
			# $endingDate =  cvt_general::DateOperation($endingDate, $daycodeSequence, "SUB");
		# }else{
			# $endingDate = $runDate->getDate();
		# }	
		my $dayDiff = 0;
		print "Finaldate:$openDate eq $endingDate\n" if ($debug);
		do	{

			if ($daycodeSequence == 0) {
				$endingDate = getEndingDate($daycodePeriod, $endingDate, $periodDaycodeId, $periodBaseDate);
				$cnt = 150;
				$cnt1 = 10;
				print "Finaldate:$openDate eq $endingDate\n" if ($debug);
				#Task#8823 Start
				if($endingDate eq '' || length($endingDate) == 0)
				{
					print "\n endingDate is Blank:$endingDate , might be periodBaseDate:$periodBaseDate Not set so skip this location \n\n";
					return 0;
				}
				#Task#8823 End
				$openDate = $endingDate;
				print "New Finaldate:$openDate eq $endingDate\n" if ($debug);
			} else {
				$cnt = 1;
				$dayDiff = 0;
				$endingDate = getEndingDate($daycodePeriod, $endingDate, $periodDaycodeId, $periodBaseDate);
				print "Finaldate:$openDate eq $endingDate\n" if ($debug);
				#Task#8823 Start
				if($endingDate eq '' || length($endingDate) == 0)
				{
					print "\n endingDate is Blank:$endingDate , might be periodBaseDate:$periodBaseDate Not set so skip this location \n\n";
					return 0;
				}
				#Task#8823 end
				# adding each business days in loop because we need to check the daycode.day field also.

				while ($cnt < 150) {
					$openDate = cvt_general::DateOperation($endingDate, $cnt, "ADD");
					print "openDate : $openDate, cnt = $cnt\n" if($debug);
					my $openDateDOW = cvt_general::DayOfWeek($openDate);
					my $openDateDOWStr =  cvt_general::GetDOW($openDateDOW);
					if ($daycodeDay =~ /$openDateDOWStr/) {
						print "$daycodeDay =~ /$openDateDOWStr/\n" if ($debug);
						$dayDiff++;
					}
					print "dayDiff : $dayDiff\n" if ($debug);
					if ($openDate ge $runDate->getDate()) {
						$cnt = 150;
					}
					$cnt++;
				}
				$cnt1++;
				print "While loop over\n" if($debug);
				if ($dayDiff < $daycodeSequence) {
					$endingDate = cvt_general::DateOperation($endingDate, 1, "SUB");
					print "Finaldate:$openDate eq $endingDate\n" if ($debug);
				} else {
					$cnt = 150;
					$cnt1 = 10;
	#				last;
				}
			}
		} while ($cnt1 < 5);
		# final day after adding the sequence should be matching with rundate then the day is open else closed

		print "dayDiff : $dayDiff\n" if ($debug);

		my $endingDateDOW = cvt_general::DayOfWeek($endingDate);
		my $endingDateDOWStr =  cvt_general::GetDOW($endingDateDOW);

		if ($dayDiff == $daycodeSequence && $openDate eq $runDate->getDate()) {
		
			if($tempdaycodeSequence < 0)
			{
				
					my $weeKAdd = 1;
					print "\n\n weeKAdd:$weeKAdd \n \n ";
					if($tempdaycodeSequence < -7)
					{	
						$weeKAdd = floor(($tempdaycodeSequence) / 7);
						$weeKAdd = $weeKAdd * -1;
					}
					
					print "\n\n New weeKAdd:$weeKAdd \n \n ";
					
					$endingDate =cvt_general::DateOperation($endingDate, (7*$weeKAdd), "ADD");
					
					print "\n\n New EndDate".$endingDate."\n\n";
					
			}
			$flag = $endingDate;
		}
		print "flag:$flag\n" if ($debug);
		# if loop breaked because of over-run then the day is not open. this is kept just for the safety so that while loop does not got to infinite in any case. It will have max of 150 iterations.
#		if ($cnt1 >= 10) {
#			$flag = 0;
#		}

		print "flag:$flag\n" if ($debug);

	}

	if ($daycodePeriod eq "W") { # Weekdays
		if ($daycodeDay =~ /$dowStr/) {
			$flag = 1;
		}
	}
	if ($daycodePeriod eq "B" && $daycodeDay =~ /$dowStr/) { #Bi-Weekly
		my $dateDiff = abs($runDate->getDateDifference($baseDate));
		if ($dateDiff % 14 == 0) {
			$flag = 1;
		}
	}
	if ($daycodePeriod eq "F" && $daycodeDay =~ /$dowStr/) { # Forth-Weekly
		my $dateDiff = abs($runDate->getDateDifference($baseDate));
		if ($dateDiff % 28 == 0) {
			$flag = 1;
		}
	}
	if ($daycodePeriod eq "E") { # Semi-Monthly
		if ($runDate->getDay() == 15 || $runDate->getDay() == $runDate->getDaysOfMonth()) {
			$flag = 1;
		}
	}
	if ($daycodePeriod eq "M") { # Monthly
		if (length($daycodeDay) == 0) {
			if ($runDate->getDay() == $daycodeSequence) {
				$flag = 1;
			}
			elsif ($daycodeSequence > 31 && $runDate->getDaysOfMonth() == $runDate->getDay()) {
				$flag = 1;
			}
		} else {
			if (uc($daycodeDay) eq "IND") { # Monthly, indeterminate
				if ($runDate->getDay() == 1) {
					$flag = 1;
				}
			}
			elsif($daycodeDay =~ /$dowStr/) {
				if ($daycodeSequence > 31) {
					my $currDay = $runDate->getDayOfWeek();
					if(($runDate->getDaysOfMonth() - $currDay) <= 7) {
						$flag = 1;
					}
				} else {
					if ($runDate->getDay() >= $daycodeSequence) {
						$flag = 1;
					}
				}
			}
		}
	}
	if ($daycodePeriod eq "Q" || $daycodePeriod eq "S" || $daycodePeriod eq "A") { # Quaterly
		my $slot = 0;
		if ($daycodePeriod eq "Q") {
			$slot = 3;
		} elsif ($daycodePeriod eq "S") {
			$slot = 6;
		} elsif ($daycodePeriod eq "A") {
			$slot = 12;
		}
		my $endingDate = cvt_general::MonthOperation($baseDate, $runDate->getDate(), $slot);
		if ($endingDate  eq $runDate->getDate()) {
			$flag = 1;
		}
	}
	if ($daycodePeriod eq "X") { # Multiple of week, depends on Sequence
		my $days = $daycodeSequence * 7;
		if ($baseDate > $runDate->getDate()) {
			my $endingDate = $runDate->addDaysToDate($days * -1);
			if ($endingDate eq $runDate->getDate()) {
				$flag = 1;
			}
		}
		if ($baseDate < $runDate->getDate()) {
			my $endingDate = $runDate->addDaysToDate($days * -1);
			if ($endingDate eq $runDate->getDate()) {
				$flag = 1;
			}
		} else {
			$flag = 1;
		}
	}
	if ($daycodePeriod eq "N") { 
		# As Needed
	}
	
	
	print "Flag:$flag\n" if ($debug);
	
	print "\n\n --------------------------IsLocationOpen End---------------------------------\n\n";
	return $flag;
}

sub getEndingDate {
	
	
	print "\n \n ------------------------------Call GetEndingDate-------------------------------\n\n ";
	my $billingPeriod = shift;
	my $runDate = new date(shift);
	
	
	print "\n\n runDate: $runDate \n \n ";
	
	
	my $daycodeId = shift;
	my $baseDate = shift;

	print $billingPeriod .",'". $runDate->getDate() ."',". $daycodeId .",". $baseDate . "\n";


	
	
	if ($daycodeId == 400) {
		return "$baseDate";
	}
	if ($billingPeriod eq "O") {

		if (length($daycodeId) == 0 || $daycodeId == 0) {
			my $endingDate = $runDate->addDaysToDate(-1); #cvt_general::DateOperation($runDate, 1, "SUB");
			return $endingDate;
		}
	}
	if ($billingPeriod eq "I") {
			my $endingDate = $runDate->addDaysToDate(-1); #cvt_general::DateOperation($runDate, 1, "SUB");
			return $endingDate;
	}
	if ($billingPeriod eq "T") {
			my $endingDate = $runDate->getDate(); #cvt_general::DateOperation($runDate, 1, "SUB");
			return $endingDate;
	}
	

	my $runDateDOW = $runDate->getDayOfWeek(); #cvt_general::DayOfWeek($runDate);
	print "rundate_dow:$runDateDOW\n" if ($debug);
	my $runDateDOWStr = $runDate->getTextFromDOW(); #cvt_general::GetDOW($runDateDOW);

	my $runDateDOM = $runDate->getDaysOfMonth(); #cvt_general::DaysOfMonth($runDate);
	print "rundate_dom:$runDateDOM\n" if ($debug);

	my $monthEndDate = $runDate->getMonthEndDate(); #lastDateOfMonth($runDate);
	print "month_enddate:$monthEndDate\n" if ($debug);

	# GETTING THE BILLINGPERIOD DAYCODE VALUES
	$sql = "SELECT type, day , period, sequence FROM daycode WHERE recid = '$daycodeId'";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my ($type, $day, $period, $sequence) = $sth->fetchrow_array();
	$sth->finish();

	print "($type, $day, $period, $sequence)" if($debug);
	my $endingDate = '';
	my $dcDOW = '';
	if (length($day) == 3) {
		$dcDOW = cvt_general::GetDOW($day);
	}
	print "DC_DOW:$dcDOW\n";

	if ($period eq "W") {
		# Checking that bill_day consist of more than one day
		if (length($day) > 3) {
			#Day fields length is more then 3 chars, means more then one day
			$endingDate = calculateEndDate($runDate->getDate(), $day, $runDateDOW);
		} elsif (length($day) == 3) {
			if (length($sequence) == 0 || $sequence == 0) {
				$endingDate = $runDate->getLastDayOfWeek($dcDOW);
			}
		}
	}
	elsif ($period eq "B") {
		if (!(length($baseDate) > 0)) {
			return "";
		}

		my $diffDays = $runDate->getDateDifference($baseDate);
		my $daysCheck = $diffDays % 14;
		print "\n\ndiffDays:$diffDays\n\n"; 
		print "\n\daysCheck:$daysCheck\n\n";
		if($daysCheck == 0){
			$endingDate = $runDate->getDate();
		} else {
			my $lastDay = $diffDays - $daysCheck;
			print "\n\lastDay:$lastDay\n\n";
			$endingDate = cvt_general::DateOperation($baseDate, $lastDay, "ADD");
		}
		print "\n\endingDate:$endingDate\n\n"; 
		
	}
	elsif ($period eq "8") {
		if (!(length($baseDate) > 0)) {
			return "";
		}

		my $diffDays = $runDate->getDateDifference($baseDate);
		my $daysCheck = $diffDays % 56;
		if($daysCheck == 0){
			$endingDate = $runDate->getDate();
		} else {
			my $lastDay = $diffDays - $daysCheck;
			$endingDate = cvt_general::DateOperation($baseDate, $lastDay, "ADD");
		}
	}
	elsif ($period eq "T") {
			$endingDate = $runDate->getDate();
	}
	elsif ($period eq "I") {
			$endingDate = $runDate->addDaysToDate(-1); #cvt_general::DateOperation($runDate, 1, "SUB");
	}
	elsif ($period eq "F") {
		if (!(length($baseDate) > 0)) {
			return "";
		}
		my $diffDays = $runDate->getDateDifference($baseDate);
		my $daysCheck = $diffDays % 28;
		if($daysCheck == 0){
			$endingDate = $runDate->getDate();
		} else {
			my $lastDay = $diffDays - $daysCheck;
			$endingDate = cvt_general::DateOperation($baseDate, $lastDay, "ADD");
		}
	}
	elsif ($period eq "M") {
		if ($day eq "IND" || (length($day) == 0 && ($sequence == "" || $sequence == 0 || $sequence > 31) )) {
			if ($monthEndDate eq $runDate->getDate()) {
				$endingDate = $runDate->getDate();
			} else {
				# Last date of previous month
				my $dd = $runDate->getDay(); #cvt_general::DatePart($runDate,"DAY");
				$endingDate = $runDate->addDaysToDate($dd * -1); #cvt_general::DateOperation($runDate,$dd,"SUB");
			}
		} elsif (length($day) == 0) {
			if ($sequence <= $runDate->getDay()) {
				$endingDate = $runDate->addDaysToDate($sequence - $runDate->getDay());
			} else {
				my $tempED = new date($runDate->addMonthsToDate(-1));
				$endingDate = $tempED->addDaysToDate($sequence - $tempED->getDay());
			}
		}
		elsif (length($day) == 3) {

			my $monED = new date($runDate->getMonthEndDate());

			if ($sequence < 31) {
				my $weekNbr = $runDate->weekOfMonth();

				$monED->setDate($monED->getLastDayOfWeek($day));
				my $lastDayWeekNbr = $monED->weekOfMonth();

				my @weekNbrArr = $sequence  =~ /[\d]{1}/g;
				if ($weekNbrArr[0] < $weekNbrArr[1]) {
					if ($weekNbr >= $weekNbrArr[1]) {
						if ($weekNbr > $weekNbrArr[1]) {
							while ($lastDayWeekNbr > $weekNbrArr[1]) {
								$monED->setDate($monED->addDaysToDate(-7));
								$lastDayWeekNbr--;
							}
							$endingDate = $monED->getDate();

						} else {
							$dcDOW = $dcDOW == 0 ? 7 : $dcDOW;
							$runDateDOW = $runDateDOW == 0 ? 7 : $runDateDOW;
							if ($runDateDOW >= $dcDOW) {
								while ($lastDayWeekNbr > $weekNbrArr[1]) {
									$monED->setDate($monED->addDaysToDate(-7));
									$lastDayWeekNbr--;
								}
								$endingDate = $monED->getDate();
							}
						}
					}
					if ($weekNbr >= $weekNbrArr[0]) {
						if ($weekNbr > $weekNbrArr[0]) {
							while ($lastDayWeekNbr > $weekNbrArr[1]) {
								$monED->setDate($monED->addDaysToDate(-7));
								$lastDayWeekNbr--;
							}
							$endingDate = $monED->getDate();
						} else {
							$dcDOW = $dcDOW == 0 ? 7 : $dcDOW;
							$runDateDOW = $runDateDOW == 0 ? 7 : $runDateDOW;
							if ($runDateDOW >= $dcDOW) {
								while ($lastDayWeekNbr > $weekNbrArr[1]) {
									$monED->setDate($monED->addDaysToDate(-7));
									$lastDayWeekNbr--;
								}
								$endingDate = $monED->getDate();
							}
						}
					} else {
						$monED->setDate($monED->addMonthToDate(-1));
						$monED->setDate($monED->getMonthEndDate());
						$monED->setDate($monED->getLastDayOfWeek($day));
						$lastDayWeekNbr = $monED->weekOfMonth();
						while ($lastDayWeekNbr > $weekNbrArr[1]) {
							$monED->setDate($monED->addDaysToDate(-7));
							$lastDayWeekNbr--;
						}
						$endingDate = $monED->getDate();
					}
				} else {
					if ($sequence <= $runDate->getDay()) {
						$endingDate = $runDate->addDaysToDate($sequence - $runDate->getDay());
					} else {
						my $tempED = new date($runDate->addMonthsToDate(-1));
						$endingDate = $tempED->addDaysToDate($sequence - $tempED->getDay());
					}
				}

			} else {

				$endingDate = $monED->getLastDayOfWeek($day);
				my $diff = $runDate->getDateDifference($endingDate);

				if ($diff < 0) {
					$monED->setDate($runDate->addMonthsToDate(-1));
					$monED->setDate($monED->getMonthEndDate());
					$endingDate = $monED->getLastDayOfWeek($day);
				}
			}
		}
	} elsif ($period eq "Q") {
		$endingDate = cvt_general::MonthOperation($baseDate, $runDate->getDate(), 3);
#		if (length($day) > 0) {
#			my $temp_str = cvt_general::DayOfWeek($endingDate);
#			$temp_str = cvt_general::GetDOW($temp_str);
#			while ($temp_str !~ /$day/) {
#				$endingDate = cvt_general::DateOperation($endingDate, 1, "ADD");
#				$temp_str = cvt_general::DayOfWeek($endingDate);
#				$temp_str = cvt_general::GetDOW($temp_str);
#			}
#		}
	} elsif ($period eq "S") {
		$endingDate = cvt_general::MonthOperation($baseDate, $runDate->getDate(), 6);
#		if (length($day) > 0) {
#			my $temp_str = cvt_general::DayOfWeek($endingDate);
#			$temp_str = cvt_general::GetDOW($temp_str);
#			while ($temp_str !~ /$day/) {
#				$endingDate = cvt_general::DateOperation($endingDate, 1, "ADD");
#				$temp_str = cvt_general::DayOfWeek($endingDate);
#				$temp_str = cvt_general::GetDOW($temp_str);
#			}
#		}
	} elsif ($period eq "A") {
		$endingDate = cvt_general::MonthOperation($baseDate, $runDate->getDate(), 12);
#		if (length($day) > 0) {
#			my $temp_str = cvt_general::DayOfWeek($endingDate);
#			$temp_str = cvt_general::GetDOW($temp_str);
#			while ($temp_str !~ /$day/) {
#				$endingDate = cvt_general::DateOperation($endingDate, 1, "ADD");
#				$temp_str = cvt_general::DayOfWeek($endingDate);
#				$temp_str = cvt_general::GetDOW($temp_str);
#			}
#		}
	} elsif ($period eq "X") {
		if (length($day) == 0 && length($sequence) > 0 && $sequence > 0) {
			if (!(length($baseDate) > 0)) {
				return "";
			}

#			my $runDateSec = cvt_general::DateToSec($runDate);
#			my $baseDateSec = cvt_general::DateToSec($baseDate);
#			my $diffDays = int(($runDateSec - $baseDateSec) / (24 * 3600));
			my $diffDays = $runDate->getDateDifference($baseDate);
			my $daysCheck = $diffDays % ($sequence * 7);
			if ($daysCheck == 0) {
				$endingDate = $runDate->getDate();
			} else {
				my $lastDay = $diffDays - $daysCheck;
				$endingDate = cvt_general::DateOperation($baseDate, $lastDay, "ADD");
			}
		}
	} elsif ($period eq "E") {

		if ($sequence == 0 || $sequence == "") {
			$sequence = 15;
		}

		if ($runDate->getDay() >= $sequence) {
			$endingDate = sprintf("%04d-%02d-%02d", $runDate->getYear(), $runDate->getMonth(), $sequence);
		} else {
			my $monED = new date($runDate->addMonthsToDate(-1));
			$endingDate = $monED->getMonthEndDate();
		}
#		my $year = cvt_general::DatePart($runDate, "YEAR");
#		my $month = cvt_general::DatePart($runDate, "MONTH");
#		my $day = cvt_general::DatePart($runDate, "DAY");
#
#		if ($day >= 15) {
#			$day = 15;
#		} else {
#			$day = cvt_general::DaysOfMonth($runDate);
#		}
#
#		$endingDate = sprintf("%04d-%02d-%02d", $year, $month, $day);
	}if ($period eq "J" || $period eq "K" || $period eq "L" ) {
		print "\n\nIN $period Period\n\n $baseDate <". $runDate->getDate()."\n\n";
		#if ($baseDate ge $runDate->getDate()) {
			my $dayCnt1 = '';
			my $dayCnt2 = '';
			my $dayCnt3 = '';
			if($period eq "J")
			{
				$dayCnt1 = 91;
				$dayCnt2 = 28;
				$dayCnt3 = 56;
			}elsif($period eq "K")
			{
				$dayCnt1 = 91;
				$dayCnt2 = 35;
				$dayCnt3 = 63;
			}elsif($period eq "L")
			{
				$dayCnt1 = 91;
				$dayCnt2 = 28;
				$dayCnt3 = 63;
			}
			
			# my $diffDays = $runDate->getDateDifference($baseDate);
			# my $daysCheck = $diffDays % $dayCnt1;
			# print "\n\ndiffDays:$diffDays\n\n"; 
			# print "\n\daysCheck:$daysCheck\n\n";
			# if($daysCheck == 0){
				# print "\n\n $dayCnt1 is process\n\n";
				# $endingDate = $runDate->getDate();
			# } else {
				# print "\n\nCheck for $dayCnt2\n\n";
				# my $diffDays = $runDate->getDateDifference($baseDate);
				# my $daysCheck = $diffDays % $dayCnt2;
				# print "\n\ndiffDays:$diffDays\n\n"; 
					# print "\n\daysCheck:$daysCheck\n\n";
				# if($daysCheck == 0){
					# print "\n\n $dayCnt2 is process\n\n";
					# $endingDate = $runDate->getDate();
				# } else {
					# print "\n\nCheck for $dayCnt3\n\n";
					# my $diffDays = $runDate->getDateDifference($baseDate);
					# my $daysCheck = $diffDays % $dayCnt3;
					# print "\n\ndiffDays:$diffDays\n\n"; 
					# print "\n\daysCheck:$daysCheck\n\n";
					# if($daysCheck == 0){
						# print "\n\n $dayCnt3 is process\n\n";
						# $endingDate = $runDate->getDate();
					# } else {
							# print "\n\n No check foudn send last date\n\n";
							# my $diffDays = $runDate->getDateDifference($baseDate);
							# print "\n\ndiffDays:$diffDays\n\n";
							# my $daysCheck = $diffDays % $dayCnt3;
							# print "\n\daysCheck:$daysCheck\n\n";
							# my $lastDay = $diffDays - $daysCheck;
							# print "\n\lastDay:$lastDay\n\n";
							# $endingDate = cvt_general::DateOperation($baseDate, $lastDay, "ADD");
					# }
				# }
				
			# }
			
				my $DayDate91 =  $baseDate;
				if($DayDate91 lt $runDate->getDate())
				{
					do{
						$DayDate91 = cvt_general::DateOperation($DayDate91 , $dayCnt1, "ADD");
						print "\n\n91DayDate:--".$DayDate91;
						
					}while($DayDate91 lt $runDate->getDate());
					
				}
				
				if($DayDate91 ge $runDate->getDate())
				{
					
					if($DayDate91 le $runDate->getDate())
					{
						print "\nIt's Time to process $dayCnt1......\n\n";
						$endingDate = $DayDate91;
						
					}else
					{
					
						my $DayDate28 = cvt_general::DateOperation($DayDate91 , $dayCnt2, "SUB");
						print "\n\DayDate$dayCnt2:--".$DayDate28;
						if($DayDate28 le $runDate->getDate())
						{
							print "\nIt's Time to process $dayCnt2......\n\n";
							$endingDate = $DayDate28;
							
						}else{
						
							my $DayDate56 = cvt_general::DateOperation($DayDate91 , $dayCnt3, "SUB");
							print "\n\DayDate$dayCnt3:--".$DayDate56;
							
							if($DayDate56 le $runDate->getDate())
							{
								print "\nIt's Time to process $dayCnt3......\n\n";
								$endingDate = $DayDate56;
								
							}else{
								
								$endingDate = cvt_general::DateOperation($DayDate91 , $dayCnt1, "SUB");;
							}
						}
					}
					
				}
		
		
	}
	
	
	print "\n \n ------------------------------END GetEndingDate-------------------------------\n\n ";
	
	return $endingDate;
}

sub getFutureEndDateFromStartDate {

	my $startDate = new date(shift);
	my $billPeriodDaycodeId = shift;
	my $billPeriodBaseDate = new date(shift);

	print $billPeriodBaseDate->getDate() if($debug);

	my $sql = "SELECT day, period, sequence, type FROM daycode WHERE recid = '$billPeriodDaycodeId'";
	print "$sql\n" if ($debug);
	my $sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my ($day, $period, $sequence, $type) = $sth->fetchrow_array();
	$sth->finish();

	print "Daycode Info:day:$day, period:$period, sequence:$sequence, type:$type\n" if ($debug);

	my $endingDate = "";

	if ($period eq "W") {
		if (length($day) == 3) {
			$endingDate = $startDate->getNextDayOfWeek($day);
		}
	} elsif ($period eq "B") {

		if ($billPeriodBaseDate->getDate() eq "0000-00-00") {
			return $billPeriodBaseDate->getDate();
		}

		my $diffDays = $startDate->getDateDifference($billPeriodBaseDate->getDate());
		print "diffDays:$diffDays\n" if($debug);
		my $daysCheck = $diffDays % 14;
		print "daysCheck:$daysCheck\n" if($debug);
		if($daysCheck == 0) {
			$endingDate = $startDate->getDate();
		} else {
			my $lastDay = $diffDays - $daysCheck;
			print "lastDay:$lastDay = $diffDays - $daysCheck\n" if($debug);
			$endingDate = $billPeriodBaseDate->addDaysToDate($lastDay + 14);
		}

	} elsif ($period eq "F") {

		if ($billPeriodBaseDate->getDate() eq "0000-00-00") {
			return $billPeriodBaseDate->getDate();
		}

		my $diffDays = $startDate->getDateDifference($billPeriodBaseDate->getDate());
		print "diffDays:$diffDays\n" if($debug);
		my $daysCheck = $diffDays % 14;
		print "daysCheck:$daysCheck\n" if($debug);
		if($daysCheck == 0) {
			$endingDate = $startDate->getDate();
		} else {
			my $lastDay = $diffDays - $daysCheck;
			print "lastDay:$lastDay = $diffDays - $daysCheck\n" if($debug);
			$endingDate = $billPeriodBaseDate->addDaysToDate($lastDay + 28);
		}

	} elsif ($period eq "I" || $period eq "T") {
		$endingDate = $startDate->getDate();
	} elsif ($period eq "E") {

		my $date = $startDate->getDay();
		if ($date <= $sequence) {
			$endingDate = $startDate->addDaysToDate($sequence - $date);
		} else {
			$endingDate = $startDate->getMonthEndDate();
		}

	} elsif ($period eq "M") {

		my $date = $startDate->getDay();
		my $year = $startDate->getYear();
		my $dom = $startDate->getDaysOfMonth();

		if (length($day) == 0) {

			if ($sequence > $dom) {
				$endingDate = $startDate->getMonthEndDate();
			} elsif ($sequence >= $date) {
				$endingDate = $startDate->addDaysToDate($sequence - $date);
			} elsif ($sequence < $date) {
				$startDate->setDate($startDate->getMonthEndDate());
				$endingDate = $startDate->addDaysToDate($sequence);
			}

		} else {
			if ($day eq "IND") {
				if (length($sequence) == 0) {
					$endingDate = $startDate->getMonthEndDate();
				} elsif ($sequence >= $date) {
					$endingDate = $startDate->addDaysToDate($sequence - $date);
				} elsif ($sequence < $date) {
					$startDate->setDate($startDate->getMonthEndDate());
					$endingDate = $startDate->addDaysToDate($sequence);
				}
			} else {
				if (length($sequence) > 0 && $sequence < 32) {
					my @weekNbr = $sequence =~ /\d/g;

				} else {
					$startDate->setDate($startDate->getMonthEndDate());
					$startDate->setDate($startDate->getLastDayOfWeek($day));
					if ($startDate->getDay() >= $date) {
						$endingDate = $startDate->getDate();
					} else {
						$startDate->setDate($startDate->addMonthsToDate(1));
						$startDate->setDate($startDate->getMonthEndDate());
						$startDate->setDate($startDate->getLastDayOfWeek($day));
						$endingDate = $startDate->getDate();
					}
				}
			}
		}
	} elsif ($period eq "Q") {
		$endingDate = AddSubMonth($startDate->getDate(), 3, "ADD");
		$endingDate = cvt_general::DateOperation($endingDate, 1, "SUB");
	} elsif ($period eq "S") {
		$endingDate = AddSubMonth($startDate->getDate(), 6, "ADD");
		$endingDate = cvt_general::DateOperation($endingDate, 1, "SUB");
	} elsif ($period eq "A") {
		$endingDate = AddSubMonth($startDate->getDate(), 12, "ADD");
		$endingDate = cvt_general::DateOperation($endingDate, 1, "SUB");
	} elsif ($period eq "X") {
		$sequence = $sequence * 7;
		if ($billPeriodBaseDate->getDate() eq "0000-00-00") {
			return $billPeriodBaseDate->getDate();
		}
		my $diffDays = $startDate->getDateDifference($billPeriodBaseDate->getDate());
		print "diffDays:$diffDays\n" if($debug);
		my $daysCheck = $diffDays % $sequence;
		print "daysCheck:$daysCheck\n" if($debug);
		if($daysCheck == 0) {
			$endingDate = $startDate->getDate();
		} else {
			my $lastDay = $diffDays - $daysCheck;
			print "lastDay:$lastDay = $diffDays - $daysCheck\n" if($debug);
			$endingDate = $billPeriodBaseDate->addDaysToDate($lastDay + $sequence);
		}
	}
	return $endingDate;
}

#sub getFutureEndDateFromStartDate {
#
#	my $startDate = new date(shift);
#	my	($billPeriodDaycodeId, $billPeriodBaseDate) = @_;
#
#	$sql = "SELECT day, period, sequence, type FROM daycode WHERE recid = '$billPeriodDaycodeId'";
#	print "$sql\n" if ($debug);
#	$sth = $dbh->prepare($sql);
#	$sth->execute() or die "$sql;\n";
#	my ($day, $period, $sequence, $type) = $sth->fetchrow_array();
#	$sth->finish();
#
#	print "Daycode Info:day:$day, period:$period, sequence:$sequence, type:$type\n" if ($debug);
#
#	my $endingDate = "";
#
#	if ($period eq "W") {
#		if (length($day) == 3) {
#			$endingDate = $startDate->getNextDayOfWeek($day);
#		}
#	} elsif ($period eq "B") {
#		$endingDate = cvt_general::DateOperation($startDate, 13, "ADD");
#	} elsif ($period eq "F") {
#		$endingDate = cvt_general::DateOperation($startDate, 27, "ADD");
#	} elsif ($period eq "E") {
#		my $date = cvt_general::DatePart($startDate, "DAY");
#		my $month = cvt_general::DatePart($startDate, "MONTH");
#		my $year = cvt_general::DatePart($startDate, "YEAR");
#		if ($date < $sequence) {
#			$endingDate = sprintf("%04d-%02d-%02d", $year, $month, $sequence);
#		} else {
#			$endingDate = sprintf("%04d-%02d-%02d", $year, $month, cvt_general::DaysOfMonth($startDate));
#		}
#	} elsif ($period eq "M") {
#		my $date = cvt_general::DatePart($startDate, "DAY");
#
#		my $year = cvt_general::DatePart($startDate, "YEAR");
#		my $dom = cvt_general::DaysOfMonth($startDate);
#		if (length($day) == 0 || $day eq "IND") {
#			$endingDate = AddSubMonth($startDate, 1, "ADD");
#			$endingDate = cvt_general::DateOperation($endingDate, 1, "SUB");
#		} else {
#			$endingDate = AddSubMonth($startDate, 1, "ADD");
#			$endingDate = lastDateOfMonth($endingDate);
#			my $dayDOW = cvt_general::GetDOW($day);
#			my $domDOW = cvt_general::DayOfWeek($endingDate);
#			if ($domDOW > $dayDOW) {
#				$endingDate = cvt_general::DateOperation($endingDate, $domDOW - $dayDOW, "SUB");
#			} elsif ($domDOW < $dayDOW) {
#				$endingDate = cvt_general::DateOperation($endingDate, (7 - $dayDOW) + $domDOW , "SUB");
#			} else {
#				$endingDate = $endingDate;
#			}
#		}
#	} elsif ($period eq "Q") {
#		$endingDate = AddSubMonth($startDate, 3, "ADD");
#		$endingDate = cvt_general::DateOperation($endingDate, 1, "SUB");
#	} elsif ($period eq "S") {
#		$endingDate = AddSubMonth($startDate, 6, "ADD");
#		$endingDate = cvt_general::DateOperation($endingDate, 1, "SUB");
#	} elsif ($period eq "A") {
#		$endingDate = AddSubMonth($startDate, 12, "ADD");
#		$endingDate = cvt_general::DateOperation($endingDate, 1, "SUB");
#	} elsif ($period eq "X") {
#		$sequence = $sequence * 7 - 1;
#		$endingDate = cvt_general::DateOperation($startDate, $sequence, "ADD");
#	}
#	return $endingDate;
#}


sub getStartingDate {
	my ($period, $endingDate, $billPeriodDaycodeId, $billPeriodBaseDate) = @_;

	
	
	my $startDate = cvt_general::DateOperation($endingDate, 1, "SUB");
	
	$startDate = getEndingDate($period, $startDate, $billPeriodDaycodeId, $billPeriodBaseDate);
	$startDate = cvt_general::DateOperation($startDate, 1, "ADD");
	
	print "START DATE2: $startDate\n";
	return $startDate;
}

sub AddSubMonth {
	my $runDate = new date(shift);
	my ($slot, $oper) = @_;

	my $endingDate;
	my ($yy, $mm, $dd) = ($runDate->getDate() =~ /(\d+)-(\d+)-(\d+)/);
	print "Run :$yy, $mm, $dd\n" if ($debug);

	my $monthIn = $slot % 12;
	my $yearIn = int($slot / 12);

	if ($oper eq "ADD") {
		$yy = $yy + $yearIn;
		$mm = $mm + $monthIn;

		if ($mm > 12) {
			$mm = $mm - 12;
			$yy++;
		}
	} elsif ($oper eq "SUB") {
		$yy = $yy - $yearIn;
		$mm = $mm - $monthIn;

		if ($mm <= 0) {
			$mm = 12 + $mm;
			$yy--;
		}
	}
	my $dd1 = "";
	if($mm == 1 || $mm == 3 || $mm == 5 || $mm == 7 || $mm == 8 || $mm == 10 || $mm == 12) {
		if ($dd > 31) {
			$dd = 31;
		}
	} elsif ($mm == 4 || $mm == 6 || $mm == 9 || $mm == 11) {
		if ($dd > 30) {
			$dd = 30;
		}
	} elsif ($mm == 2) {
		if(cvt_general::IsLeapYear($yy)) {
			if ($dd > 29) {
				$dd = 29;
			}
		} else {
			if ($dd > 28) {
				$dd = 28;
			}
		}
	}
	$endingDate = sprintf("%04d-%02d-%02d",$yy, $mm, $dd);
	return $endingDate;
}

sub countTotalAmount {
	my ($startDt, $endDt, $customerId, $clientId, $clientLocId, $flag_AUPIA) = @_;

	my $totalAmount = 0;
	my %locationHolidayTotal;
	my %prodCommentStr;
	my %clientProdLink;
	my %prodList;
	my @prodListArr;
	my @commentStr;
	my $locationHolidayTotal = 0;


	$sql = "SELECT DISTINCT(productid) FROM standarddraw WHERE effdt <= '$endDt' AND clientlocid = '$clientLocId' AND customerlocid = '$customerId' AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > '$startDt')";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $refProductId = $sth->fetchall_arrayref();
	$sth->finish();

	my @productIds = @{$refProductId};
	foreach my $productId (@productIds) {
		$productId = $productId->[0];

		$sql = "SELECT p.recid, p.sdesc,  p.daycodeid, p.basepubdate FROM product p WHERE  p.recid = '$productId' /*AND p.producttype = 'PU'*/ AND (p.endeffdt IS NULL OR p.endeffdt = '0000-00-00' OR p.endeffdt > '$endDt')";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my ($pRecId, $pSDesc, $pDaycodeId, $pBasePubDate) = $sth->fetchrow_array();
		$sth->finish();

		if($pRecId != $productId) {
			next;
		}

		if (not exists $prodList{$pSDesc}) {
			push @prodListArr, $pSDesc;
			$prodList{$pSDesc} = 0;
			$prodList{$pSDesc . "_PHoliday"} = 0;
			$prodList{$pSDesc . "_LHoliday"} = 0;
		}

		$sql = "SELECT day, period, sequence, type FROM daycode WHERE recid = '$pDaycodeId'";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my ($pDay, $pPeriod, $pSequence, $pType) = $sth->fetchrow_array();
		$sth->finish();

		my $tempDt = $startDt;
		while ($tempDt le $endDt) {

			my $locationOpen = 1;
			my $productOpen = 1;
			my $locationHoliday = 0;
			my $productHoliday = 0;


			# select daycodeid of location from routelink
			$sql = "SELECT daycodeid, credithold FROM routelink WHERE clientid = '$clientId' AND locationid = '$customerId' AND (endeffdt = '0000-00-00' OR endeffdt IS NULL OR endeffdt > '$startDt')";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my ($cDaycodeId, $cCreditHold) = $sth->fetchrow_array();
			$sth->finish();

			if(length($cCreditHold) > 0 && $cCreditHold eq "Y") {
				$locationOpen = 0;
			}

			if ($locationOpen && length($cDaycodeId) > 0 && $cDaycodeId > 0) {
				$locationOpen = isLocationOpen($tempDt, $cDaycodeId);
			}

			# determine for customer vacation date
			if ($locationOpen) {
				$sql = "SELECT COUNT(*) FROM customervacation WHERE locationid = '$customerId' AND '$tempDt' >= fromdate AND '$tempDt' < todate";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my $isVacation = ($sth->fetchrow_array())[0];
				$sth->finish();
				if($isVacation > 0) {
					# location is off due to vacation
					$locationHoliday = 1;
				}
			}

			# determine whether it's holiday or not
			if ($locationOpen) {
				$sql = "SELECT COUNT(*) FROM holidaylocationlink hll, holidays h, holidayslink hl WHERE hl.clientid = '$clientId' AND hl.holidaysid = h.recid AND h.recid = hll.holidaysid AND hll.locationid = '$customerId' AND h.holidaydate = '$tempDt' AND (h.endeffdt IS NULL OR h.endeffdt = '0000-00-00' OR h.endeffdt > '$tempDt') AND (hl.endeffdt IS NULL OR hl.endeffdt = '0000-00-00' OR hl.endeffdt > '$tempDt')";
				print "$sql;\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my $isLoctionHoliday = ($sth->fetchrow_array())[0];
				$sth->finish();
				if($isLoctionHoliday > 0) {
					#location is off due to holiday
					$locationHoliday = 1;
				}
			}

			# determine product holiday
			$sql = "SELECT COUNT(*) FROM product, holidays, holidaydetail  WHERE product.recid = '$productId' /*AND product.producttype = 'PU'*/ AND product.holidaysetid = holidaydetail.holidaysetid AND holidaydetail.holidaysid = holidays.recid AND holidays.holidaydate = '$tempDt' AND (holidays.endeffdt IS NULL OR holidays.endeffdt = '0000-00-00' OR holidays.endeffdt > '$tempDt')";
			print "$sql;\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my $prodHoliday = ($sth->fetchrow_array())[0];
			$sth->finish();

			# if product is on holiday then consider that location is also on holiday.
			if ($prodHoliday > 0) {
				$productHoliday = 1;
			}

			$productOpen = isLocationOpen($tempDt, $pDaycodeId, $pBasePubDate);

			if ($locationOpen && $productOpen) {
				my $seasonDetailId = getSeasonDetailId($productId, $tempDt);
				my $dow = cvt_general::DayOfWeek($tempDt);
				my $dow_str = cvt_general::GetDOW($dow);
				my $field = "qty" . lc($dow_str);

				if ($pDay eq "IND") {
					$field = "qtyind";
				}

				$sql = "SELECT $field, pricecodeid FROM standarddraw WHERE effdt <= '$tempDt' AND clientlocid = '$clientLocId' AND customerlocid = '$customerId' AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > '$tempDt') AND productid = '$productId' AND seasondetailid = '$seasonDetailId' ORDER BY effdt DESC LIMIT 1";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my ($quantity, $pricecodeId) = $sth->fetchrow_array();
				$sth->finish();
				
				$sql = "SELECT quantity FROM specialdraw WHERE specificproductdate = '$tempDt' AND clientlocid = '$clientLocId' AND locationid = '$customerId' AND productid = '$productId' LIMIT 1";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my $specialquantity = ($sth->fetchrow_array())[0];
				$sth->finish();

				$sql = "SELECT amount FROM productprice WHERE productid = '$productId' AND pricecodeid = '$pricecodeId' AND salecost = 'S' AND effdt <= '$tempDt' ORDER BY effdt DESC LIMIT 1";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my $saleAmount = ($sth->fetchrow_array())[0];
				$sth->finish();

				if (length($quantity) == 0) {
					$quantity = 0;
				}
				
				if(length($specialquantity) > 0) {
					$quantity = $specialquantity;
				}

				if (length($saleAmount) == 0) {
					$saleAmount = 0;
				}

				$prodList{$pSDesc} += $quantity * $saleAmount;
#				if (!$locationHoliday && !$productHoliday) {
#					$prodList{$pSDesc} += $quantity * $saleAmount;
#				} else {

				if (($locationHoliday && $productHoliday) || $locationHoliday) {

					$prodList{$pSDesc . "_LHoliday"} += $quantity * $saleAmount;

				} elsif ($productHoliday) {

					$prodList{$pSDesc . "_PHoliday"} += $quantity * $saleAmount;
				}
#				}

				print $pSDesc ." -> " . $prodList{$pSDesc} ."\n" if($debug);
				print $pSDesc."_LHoliday" ." -> " . $prodList{$pSDesc."_LHoliday"} ."\n" if($debug);
				print $pSDesc."_PHoliday" ." -> " . $prodList{$pSDesc."_PHoliday"} ."\n" if($debug);
			}

			$tempDt = cvt_general::DateOperation($tempDt, 1, "ADD");
			print "TempDt:$tempDt, EndDt:$endDt\n" if ($debug);

		}

		if ($flag_AUPIA) {
			$commentStr[0] .= $pSDesc .":". $prodList{$pSDesc} .",";
			$commentStr[1] .= $pSDesc .":". $prodList{$pSDesc."_PHoliday"} .",";
			$commentStr[2] .= $pSDesc .":". $prodList{$pSDesc."_LHoliday"} .",";
			$totalAmount += $prodList{$pSDesc} - $prodList{$pSDesc."_PHoliday"} - $prodList{$pSDesc."_LHoliday"};
			$locationHolidayTotal += $prodList{$pSDesc."_LHoliday"};

		} else {

			$sql = "SELECT recid, invoicingent, invoicingentlocid FROM standarddraw WHERE effdt <= '$startDt' AND clientlocid = '$clientLocId' AND customerlocid = '$customerId' AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > '$startDt') ORDER BY effdt DESC LIMIT 1";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my ($sdDrawId, $invoicingEnt, $invoicingEntLocId) = $sth->fetchrow_array();
			$sth->finish();

			if ($invoicingEnt eq "W") {
				if (not exists $clientProdLink{$invoicingEntLocId}) {
					$clientProdLink{$invoicingEntLocId} = $productId;
				} else {
					$clientProdLink{$invoicingEntLocId} .= "," . $productId;
				}
			} else {
				if (not exists $clientProdLink{$clientLocId}) {
					$clientProdLink{$clientLocId} = $productId;
				} else {
					$clientProdLink{$clientLocId} .= "," . $productId;
				}
			}

			print $clientProdLink{$invoicingEntLocId} . "\n" if ($debug);

			$totalAmount = $prodList{$pSDesc} - $prodList{$pSDesc . "_PHoliday"} - $prodList{$pSDesc . "_LHoliday"};
			$prodCommentStr{$productId} = $totalAmount .",". $pSDesc .":". $prodList{$pSDesc} ."," . $pSDesc .":". $prodList{$pSDesc . "_PHoliday"} .",". $pSDesc .":". $prodList{$pSDesc . "_LHoliday"} .",";
			$locationHolidayTotal{$productId} = $prodList{$pSDesc . "_LHoliday"};
		}
	}

	if ($flag_AUPIA) {
		my $retnStr = "SD:". $commentStr[0] ."~PH:". $commentStr[1] ."~VH:". $commentStr[2];
		if (length($retnStr) > 250) {
			$retnStr = "SD:". $commentStr[0] ."~PH:". $commentStr[1] ."~VH:Tot:". $locationHolidayTotal;
		}

		return $totalAmount ."=". $retnStr;
	} else {
		my $retnVal;
		foreach my $clientLocId (keys %clientProdLink) {
			my $tmpProdList = $clientProdLink{$clientLocId};
			my @tmpProdArr = split(/,/, $tmpProdList);
			my $retnStr = "";
			my $commentStrSD = "";
			my $commentStrPH = "";
			my $commentStrLH = "";
			my $locLHTotal = 0;
			my $locTotal = 0;
			foreach my $tempProdId (@tmpProdArr) {
				if (length($tempProdId) > 0) {
					my $tempStr = $prodCommentStr{$tempProdId};
					my @tempArr = split(/,/, $tempStr);
					$locTotal += $tempArr[0];
					$commentStrSD .= $tempArr[1];
					$commentStrPH .= $tempArr[2];
					$commentStrLH .= $tempArr[3];
					$locLHTotal += $locationHolidayTotal{$tempProdId};
				}
			}
			my $retnStr = "SD:". $commentStrSD ."~PH:". $commentStrPH ."~VH:". $commentStrLH;
			if (length($retnStr) > 250) {
				$retnStr = "SD:". $commentStrSD ."~PH:". $commentStrPH ."~VH:Tot:". $locLHTotal;
			}
			if (length($retnVal) == 0) {
				$retnVal = $clientLocId ."##". $locTotal ."##". $retnStr;
			} else {
				$retnVal .= "||" . $clientLocId ."##". $locTotal ."##". $retnStr;
			}
		}

		return $retnVal;

	}
}


sub getSeasonDetailId {
	my $productId = shift;
	my $runDate = new date(shift);

	# finding the seasonid for the selected location
	$sql = "SELECT sd.recid, CONCAT_WS('-',YEAR('". $runDate->getDate() ."'), sd.frommonth,sd.fromdate), CONCAT_WS('-',YEAR('". $runDate->getDate() ."'), sd.tomonth,sd.todate) FROM season s, seasondetail sd, product p WHERE p.recid = '$productId' /*AND p.producttype = 'PU'*/ AND p.seasonid = s.recid AND s.recid = sd.seasonid AND (s.endeffdt IS NULL OR s.endeffdt = '0000-00-00' OR s.endeffdt > '". $runDate->getDate() ."')";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $refSeasonDetail = $sth->fetchall_arrayref();
	$sth->finish();

	my @seasondetail = @$refSeasonDetail;
	my $seasonDetailId = 0;
	foreach my $record (@seasondetail) {
		my $fromDate = $record->[1];
		my $toDate = $record->[2];
		if($fromDate gt $toDate) {
			my $currYear = (localtime)[5] + 1900;
			$currYear++;
			$toDate = $currYear . substr($toDate,4);
		}
		if ($runDate->getDate() ge $fromDate && $runDate->getDate() le $toDate) {
			$seasonDetailId = $record->[0];
		}
	}
	return $seasonDetailId;
}

sub processManInvoice {
	my ($clientId, $clientLocId, $specificRouteId) = @_;
	if(length($clientId) == 0 || length ($clientLocId) == 0 || length($runDate->getDate()) == 0 || length($specificRouteId) == 0) {
		print "Not adequate data\n";
		return ;
	}

	my $spRouteLocIds = "";
	$sql = $archObj->processSQL("SELECT DISTINCT(locationid) FROM specificrouteloc WHERE pl.specificrouteid = '$specificRouteId'");
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	if ($sth->rows() == 0) {
		$spRouteLocIds = "0";
		print "No locations found\n";
		return ;
	} else {
		while (my @record = $sth->fetchrow_array()) {
			$spRouteLocIds .= $record[0] . ",";
		}
		$spRouteLocIds =~ s/,$//;
		if (length($spRouteLocIds) == 0) {
			$spRouteLocIds = "0";
		}
	}
	$sth->finish();

	$sql = "SELECT DISTINCT(rl.locationid) FROM routelink rl, daycode dc WHERE rl.locationid IN ($spRouteLocIds) AND rl.clientid = '$clientId' AND rl.billingdaycodeid = dc.recid AND dc.period = 'O'";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $refLocations = $sth->fetchall_arrayref();
	$sth->finish();

	my @custLocations = @$refLocations;

	foreach my $record (@custLocations) {
		my $customerLocId = $record->[0];
		if (length (cvt_general::trim($customerLocId)) == 0) {
			$customerLocId = 0;
		}

		# CHECKING OF BILLINGDAYCODEID AND BILLINGPERIODDAYCODEID IN ROUTELINK
		# AND ALSO CHECK THAT TODAY IS BILLINGDAY OR NOT.
		# AND ALSO CALCULATE THE ENDINGDATE.

		$sql = "SELECT billingdaycodeid, billingperioddaycodeid, billingbasedate, billingperiodbasedate, piaflag, period FROM routelink LEFT JOIN daycode dc on billingperioddaycodeid = dc.recid  WHERE clientid = '$clientId' and locationid = '$customerLocId' AND (billingdaycodeid IS NOT NULL AND billingdaycodeid > 0) AND (billingperioddaycodeid IS NOT NULL AND billingperioddaycodeid > 0)";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my ($billDaycodeId, $billPeriodDaycodeId, $billBaseDate, $billPeriodBaseDate, $piaFlag, $billPeriodDaycodePeriod) = $sth->fetchrow_array();
		$sth->finish();
		
		if ($piaFlag eq "N") {
		print "PIA-FLG is N so Skipp\n";
			next ;
		}
		
		if ($billPeriodDaycodePeriod eq "B" && ($billPeriodBaseDate eq '0000-00-00' || $billPeriodBaseDate eq '') ) {
			print "When BillingPeriod = 'B' BillingPeriodBaseDate must be set \n";
			cvt_general::error_log01("SE024","","","D059","2","0","$clientId","0","0","billingperiodbasedate Not Set for CustomerLocId:$customerLocId for billingperioddaycodeid = $billPeriodDaycodeId");
			next;			
		}
		
		my $isBillingDay = isLocationOpen($runDate->getDate(), $billDaycodeId, $billBaseDate,  $billPeriodDaycodeId, $billPeriodBaseDate);

		if ($isBillingDay == 0) {
			next ;
		}

		my $billingFlag = "N";
		if ($piaFlag eq "Y") {
			$billingFlag = "Y";
		}

		$sql = "SELECT type, period, sequence FROM daycode WHERE recid = '$billDaycodeId'";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my ($type, $period, $sequence) = $sth->fetchrow_array();
		$sth->finish();

		# WHEN TYPE IS "L" THEN CHANGE THE RUNDATE BACK TO THE RELATIVE DAYS FOR THE BILLINGDAYCODEID
		my $tempRunDate = '';
		if($type eq "L"){
			$tempRunDate = $runDate->getDate();
			# Finding the lagging period
			my $lag = $sequence * 7;
			$runDate->setDate($runDate->addDaysToDate($lag * -1));
		} # end of lagging period condition.

		my $endingDate = getEndingDate($period, $runDate->getDate(), $billPeriodDaycodeId, $billPeriodBaseDate);

		if (length($endingDate) == 0) {
			#Billing date not found move to next product
			next ;
		}

		if (length($tempRunDate) > 0) {
			$runDate->setDate($tempRunDate);
			$tempRunDate = '';
		}

		# PROCESS OF THE TRANSACTION RECORDS FOR WHICH
		# CLOSEDCUSTDATE IS NULL OR ZERO.
		my $deAmount = 0;
		my $puAmount = 0;
		my $adAmount = 0;
		my $totalAmount = 0;

		$sql = "SELECT DISTINCT(productid) FROM  standarddraw WHERE customerlocid = '$customerLocId' AND clientlocid = '$clientLocId' AND effdt <= '$endingDate' ORDER BY effdt DESC";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my $refTempProductList = $sth->fetchall_arrayref();
		my @tempProductList = @{$refTempProductList};
		$sth->finish();

		my $prodList = "";
		foreach my $record (@tempProductList) {
			$sql = "SELECT pricecodeid FROM standarddraw WHERE productid = '$record->[0]' AND customerlocid = '$customerLocId' AND clientlocid = '$clientLocId' AND effdt <= '$endingDate' AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > '$endingDate') ORDER BY effdt DESC LIMIT 1";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my $priceCodeId = ($sth->fetchrow_array())[0];
			$sth->finish();
			if (length($priceCodeId) == 0 || $priceCodeId == 0) {
				$prodList .= $record->[0] . ",";
			}
		}

		$prodList =~ s/,$//;
		if (length($prodList) == 0) {
			$prodList = 0;
		}

		$sql = $archObj->processSQL("UPDATE transactivity, specificproduct SET transactivity.closeddatecust = '$val_INDEF', transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND (transactivity.closeddatecust IS NULL OR transactivity.closeddatecust = '0000-00-00') AND transactivity.locationid = '$clientLocId' AND transactivity.customerlocid = '$customerLocId' AND transactivity.type IN ('DE', 'PU', 'AD') AND transactivity.specificproductid = specificproduct.recid AND specificproduct.datex <= '$endingDate' AND specificproduct.productid IN ($prodList)");
		print "$sql\n" if ($debug);
		$dbh->do($sql) or die "$sql;\n";

		$sql = $archObj->processSQL("SELECT COUNT(*) FROM transactivity ta, specificproduct sp WHERE ta.recid <= '$maxTaRecId' AND ta.type IN ('DE', 'PU', 'AD') AND (ta.closeddatecust IS NULL OR ta.closeddatecust = '0000-00-00') AND ta.specificproductid = sp.recid AND sp.datex <= '$endingDate' AND ta.customerlocid = '$customerLocId' AND ta.locationid = '$clientLocId'");
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my $isRecordExists = ($sth->fetchrow_array())[0];
		$sth->finish();

		if ($isRecordExists > 0) {

#			$sql = "SELECT recid, billingflag FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND invdate = '". $runDate->getDate() ."' AND periodenddate = '$endingDate' AND type = 'I' AND source = 'T'";
			$sql = "SELECT recid, billingflag FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND periodenddate = '$endingDate' AND type = 'I' AND source = 'T'";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my ($piRecId, $piBillingFlag) = $sth->fetchrow_array();
			$sth->finish();

			if ((($piBillingFlag eq "Y" && $billingFlag eq "N") || $piBillingFlag eq "P") && length($piRecId) > 0 && $piRecId > 0) {
				next;
			}

			updateVendingLocs($clientLocId, $customerLocId, $endingDate);

			$sql = $archObj->processSQL("UPDATE transactivity, specificproduct SET transactivity.closeddatecust = '". $runDate->getDate() ."', transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.type IN ('DE', 'PU', 'AD') AND (transactivity.closeddatecust IS NULL OR transactivity.closeddatecust = '0000-00-00') AND transactivity.specificproductid = specificproduct.recid AND specificproduct.datex <= '$endingDate' AND transactivity.customerlocid = '$customerLocId' AND transactivity.locationid = '$clientLocId'");
			print "$sql\n" if ($debug);
			my $rows = $dbh->do($sql) or die "$sql;\n";

			if ($rows > 0) {

				# Calculate the DE Amount
				$sql = $archObj->processSQL("SELECT SUM(actquantity * unitsales) as desum FROM transactivity WHERE transactivity.recid <= '$maxTaRecId' AND locationid = '$clientLocId' AND customerlocid = '$customerLocId' AND closeddatecust = '". $runDate->getDate() ."' AND (type = 'DE' OR type = 'AD')");
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				$deAmount = ($sth->fetchrow_array())[0];
				$sth->finish();

				$deAmount = sprintf("$format",$deAmount);

				# Calculate the PU Amount
				$sql = $archObj->processSQL("SELECT SUM(actquantity * unitsales) as pusum FROM transactivity WHERE transactivity.recid <= '$maxTaRecId' AND locationid = '$clientLocId' AND customerlocid = '$customerLocId' AND closeddatecust = '". $runDate->getDate() ."' AND type = 'PU'");
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				$puAmount = ($sth->fetchrow_array())[0];
				$sth->finish();

				$puAmount = sprintf("$format",$puAmount);

				$totalAmount = $deAmount - $puAmount;
				$totalAmount = sprintf("$format",$totalAmount);

				# NOW INSERT A RECORD INTO THE PRODUCTINVOICE FOR INVOICING

				if (length($piRecId) > 0 && $piRecId > 0) {
					$sql = "UPDATE productinvoice SET totalamount = '$totalAmount', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid = '$piRecId'";
					print "$sql\n" if ($debug);
					$dbh->do($sql) or die "$sql;\n";
				} else {
											my $val_ADPMT = "0";
                                       		$sql = "SELECT DISTINCT(locationid) FROM locationsystem WHERE recid = 'ADPMT' AND locationid = $clientLocId AND charvar = 'Y' AND (endeffdt = '0000-00-00' OR endeffdt is null OR endeffdt > '". $runDate->getDate() ."')";
	                                        print "$sql\n" if ($debug);
	                                        $sth = $dbh->prepare($sql);
	                                        $sth->execute() or die "$sql;\n";
                                            $val_ADPMT = $sth->rows();
	                                        $sth->finish();


	                                                $sql = "INSERT INTO productinvoice (clientlocid, customerlocid, type, invdate, periodenddate, totalamount, billingflag, source) VALUES ('$clientLocId', '$customerLocId', 'I', '". $runDate->getDate() ."', '$endingDate', '$totalAmount', '$billingFlag', 'T')";
	                                                print "$sql\n" if ($debug);
	                                                $dbh->do($sql) or die "$sql;\n";
	                                                my $productInvoiceId = $dbh->{'mysql_insertid'};
                                                #/* Task#8394 Starts*/
                                                if($productInvoiceId) {
	                                                print "\nCall InvoicetaLink --->'transactivity','closeddatecust',$clientId,$clientLocId,$customerLocId,$runDate->getDate(),$productInvoiceId,$endingDate,'T','1','DE','PU'\n";
														
	                                                cvt_general::createInvoiceTaLink($dbh,'transactivity','closeddatecust',$clientId,$clientLocId,$customerLocId,$runDate->getDate(),$productInvoiceId,$endingDate,'T','1',"'DE','PU'",'SE024',$prodList,'');
                                                }
                                                #/* Task#8394 Ends*/

                                                if($val_ADPMT > 0) {
	                                                my $val_PRODP = "0";
	                                                $sql = "SELECT realvar FROM locationsystem WHERE recid = 'PRODP' AND locationid = '$clientLocId' AND (endeffdt = '0000-00-00' OR endeffdt is null OR endeffdt > '". $runDate->getDate() ."')";
	                                                print "$sql\n" if ($debug);
	                                                $sth = $dbh->prepare($sql);
	                                                $sth->execute() or die "$sql;\n";
                                                        $val_PRODP = ($sth->fetchrow_array())[0];
	                                                $sth->finish();


	                                                $sql = "SELECT SUM(totalamount),periodenddate FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type IN('P','C') AND billingflag = 'Y' AND source = 'T' GROUP BY periodenddate";
	                                                print "$sql\n" if ($debug);
	                                                $sth = $dbh->prepare($sql);
	                                                $sth->execute() or die "$sql;\n";
			                                while (my ($chkTotalAmount,$periodenddate) = $sth->fetchrow_array()) {

													my $abschkTotalAmount = abs($chkTotalAmount);
													my $maxprodp = $abschkTotalAmount + $val_PRODP;
													my $minprodp = $abschkTotalAmount - $val_PRODP;

													$sql = "UPDATE productinvoice SET billingflag = 'Y', archupdt = IF(archupdt = 'P', 'U', archupdt)  WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type = 'I' AND source = 'T' AND periodenddate = '$periodenddate' ";
                                                    print "$sql\n" if ($debug);
                                                    $dbh->do($sql) or die "$sql;\n";

													$sql = "SELECT SUM(totalamount) FROM productinvoice WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type = 'I' AND source = 'T' AND totalamount < $maxprodp AND totalamount > $minprodp AND periodenddate = '$periodenddate' GROUP BY periodenddate";
	                                                print "$sql\n" if ($debug);
	                                                $sth = $dbh->prepare($sql);
	                                                $sth->execute() or die "$sql;\n";
													my $iexist = $sth->rows();

                                                        $chkTotalAmount = abs($chkTotalAmount);
                                                        if($iexist > 0) {
                                                        	my $vendDiff = $chkTotalAmount;

	                                                        $sql = "UPDATE productinvoice SET billingflag = 'P', archupdt = IF(archupdt = 'P', 'U', archupdt)  WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type IN('P','C') AND periodenddate = '$periodenddate' AND billingflag = 'Y' AND source = 'T'";
	                                                        print "$sql\n" if ($debug);
	                                                        $dbh->do($sql) or die "$sql;\n";

															$sql = "UPDATE productinvoice SET billingflag = 'P' , archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type = 'I' AND billingflag = 'Y' AND source = 'T' AND periodenddate = '$periodenddate' ";
															print "$sql\n" if ($debug);
															$dbh->do($sql) or die "$sql;\n";
                                                        	}
                                                            }
                                                         $sth->finish();
                                                	}
				}
			}
		}
	}
	return;
}

sub setINDEF {
	my ($clientId, $clientLocId) = @_;

	$sql = "SELECT intvar FROM system WHERE recid = 'PURTA' AND (endeffdt = '0000-00-00' OR endeffdt IS NULL OR endeffdt > '". $runDate->getDate() ."')";
	print "$sql\n;" if($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my ($val_PURTA) = $sth->fetchrow_array();
	$sth->finish();

	$sql = "SELECT datevar FROM system WHERE recid = 'INDEF' AND (endeffdt = '0000-00-00' OR endeffdt IS NULL OR endeffdt > '". $runDate->getDate() ."')";
	print "$sql\n;" if($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my ($val_INDEF) = $sth->fetchrow_array();
	$sth->finish();

	if (length($val_PURTA) == 0 || $val_PURTA == 0) {
		$val_PURTA = 90; # DEFAULT VALUE IF VARIABLE IS NOT AVAILABLE DUE TO SOME REASON
		return;
	}

	my $cutOffDate = cvt_general::DateOperation($runDate->getDate(), $val_PURTA, "SUB");
	my $totalCust = 0;
	my $totalVend = 0;
	my $totalVendInv = 0;

	# ClosedDateVend - Ta
	$sql = "SELECT recid FROM product WHERE clientid = '$clientId' AND (payablesdaycodeid IS NULL OR payablesdaycodeid = 0 OR payablesdaycodeid = '' OR  billingperioddaycodeid IS NULL OR billingperioddaycodeid = 0 OR billingperioddaycodeid = '')";
	print "$sql\n;" if($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my ($refVendProbProucts) = $sth->fetchall_arrayref();
	$sth->finish();

	foreach my $probProduct (@{$refVendProbProucts}) {
		$probProduct = $probProduct->[0];

		$sql = $archObj->processSQL("UPDATE transactivity, specificproduct SET transactivity.closeddatevend = '$val_INDEF', transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.locationid = '$clientLocId' AND transactivity.datet < '$cutOffDate' AND transactivity.specificproductid = specificproduct.recid AND specificproduct.productid = '$probProduct' AND (transactivity.closeddatevend IS NULL OR transactivity.closeddatevend = '0000-00-00')");
		print "$sql\n;" if($debug);
		$totalVend += $dbh->do($sql);
	}

	print "totalVend:$totalVend\n" if($debug);

	# ClosedDateVendInv - Ta
	$sql = "SELECT recid FROM product WHERE clientid = '$clientId' AND (feedaycodeid IS NULL OR feedaycodeid = 0 OR feedaycodeid = '' OR  feeperioddaycodeid IS NULL OR feeperioddaycodeid = 0 OR feeperioddaycodeid = '')";
	print "$sql\n;" if($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my ($refInvProbProucts) = $sth->fetchall_arrayref();
	$sth->finish();

	foreach my $probProduct (@{$refInvProbProucts}) {
		$probProduct = $probProduct->[0];

		$sql = $archObj->processSQL("UPDATE transactivity, specificproduct SET transactivity.closeddatevendinv = '$val_INDEF', transactivity.archupdt = IF(transactivity.archupdt = 'P', 'U', transactivity.archupdt) WHERE transactivity.recid <= '$maxTaRecId' AND transactivity.locationid = '$clientLocId' AND transactivity.datet < '$cutOffDate' AND transactivity.specificproductid = specificproduct.recid AND specificproduct.productid = '$probProduct' AND (transactivity.closeddatevendinv IS NULL OR transactivity.closeddatevendinv = '0000-00-00')");
		print "$sql\n;" if($debug);
		$totalVendInv += $dbh->do($sql);
	}

	print "totalVendInv:$totalVendInv\n" if($debug);
	# ClosedDateVendInv - TaSC
	$sql = "SELECT recid FROM product WHERE clientid = '$clientId' AND (scdaycodeid IS NULL OR scdaycodeid = 0 OR scdaycodeid = '' OR  scperioddaycodeid IS NULL OR scperioddaycodeid = 0 OR scperioddaycodeid = '')";
	print "$sql\n;" if($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my ($refInvProbProucts) = $sth->fetchall_arrayref();
	$sth->finish();

	foreach my $probProduct (@{$refInvProbProucts}) {
		$probProduct = $probProduct->[0];

		$sql = $archObj->processSQL("UPDATE transactivitysc, specificproduct SET transactivitysc.closeddatevendinv = '$val_INDEF', transactivitysc.archupdt = IF(transactivitysc.archupdt = 'P', 'U', transactivitysc.archupdt) WHERE transactivitysc.recid <= '$maxTaSCRecId' AND transactivitysc.locationid = '$clientLocId' AND transactivitysc.datet < '$cutOffDate' AND transactivitysc.specificproductid = specificproduct.recid AND specificproduct.productid = '$probProduct' AND (transactivitysc.closeddatevendinv IS NULL OR transactivitysc.closeddatevendinv = '0000-00-00')");
		print "$sql\n;" if($debug);
		$totalVendInv += $dbh->do($sql);
	}

	print "SC:totalVendInv:$totalVendInv\n" if($debug);
	# ClosedDateCust
	$sql = "SELECT locationid, billingdaycodeid, billingperioddaycodeid, scdaycodeid, scperioddaycodeid FROM routelink WHERE clientid = '$clientId' AND (billingdaycodeid IS NULL OR billingdaycodeid = 0 OR billingdaycodeid = '' OR billingperioddaycodeid IS NULL OR billingperioddaycodeid = 0 OR billingperioddaycodeid = '')";
	print "$sql\n;" if($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my ($refProbLocations) = $sth->fetchall_arrayref();
	$sth->finish();

	foreach my $probLocation (@{$refProbLocations}) {
		my ($custLocId, $billId, $billPeriodId) = @{$probLocation};

		$sql = $archObj->processSQL("UPDATE transactivity ta SET ta.closeddatecust = '$val_INDEF', ta.archupdt = IF(ta.archupdt = 'P', 'U', ta.archupdt) WHERE ta.recid <= '$maxTaRecId' AND ta.locationid = '$clientLocId' AND (ta.closeddatecust = '0000-00-00' OR ta.closeddatecust IS NULL) AND ta.datet < '$cutOffDate' AND ta.customerlocid = '$custLocId'");
		print "$sql;\n" if($debug);
		$totalCust += $dbh->do($sql);

	}

	print "totalCust:$totalCust\n" if($debug);
	# ClosedDateCust - SC
	$sql = "SELECT locationid FROM routelink WHERE clientid = '$clientId' AND (scdaycodeid IS NULL OR scdaycodeid = 0 OR scdaycodeid = '' OR scperioddaycodeid IS NULL OR scperioddaycodeid = 0 OR scperioddaycodeid = '')";
	print "$sql\n;" if($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my ($refProbLocations) = $sth->fetchall_arrayref();
	$sth->finish();

	foreach my $probLocation (@{$refProbLocations}) {
		my ($custLocId) = @{$probLocation};

		$sql = $archObj->processSQL("UPDATE transactivitysc ta SET ta.closeddatecust = '$val_INDEF', ta.archupdt = IF(ta.archupdt = 'P', 'U', ta.archupdt) WHERE ta.recid <= '$maxTaSCRecId' AND ta.locationid = '$clientLocId' AND (ta.closeddatecust = '0000-00-00' OR ta.closeddatecust IS NULL) AND ta.datet < '$cutOffDate' AND ta.customerlocid = '$custLocId'");
		print "$sql\n;" if($debug);
		$totalCust += $dbh->do($sql);

	}

	print "SC:totalCust:$totalCust\n" if($debug);
}
#Task#8756 Start
sub createLIServiceChargeCust {
	my ($clientId, $clientLocId) = @_;
	
	print "\n-----------------------createLIServiceChargeCust Process Start---------------------\n";
	$sql = "SELECT /*SE024*/ datevar FROM system WHERE recid = 'INDEF'";
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $dtINDEF = date->new(($sth->fetchrow_array())[0]);
	$sth->finish();
	
	
	$sql = "SELECT /*SE024*/ distinct(customerlocid)  FROM servicecharge WHERE clientlocid = '$clientLocId' AND customerlocid > 0 AND type = 'LI' ";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my $rows = $sth->rows();
		my $refLocations = $sth->fetchall_arrayref();
		$sth->finish();

		my @custLocations = @$refLocations;
		foreach my $record (@custLocations) {
			my $customerLocId = $record->[0];
			#my $servicechargepriceid = $record->[1];
			#my $servicechargeid = $record->[2];
			
			$sql = "SELECT /*SE024*/ scdaycodeid, basescdate, scperioddaycodeid, basescperioddate, piaflag FROM routelink WHERE clientid = '$clientId' and locationid = '$customerLocId' AND (scdaycodeid IS NOT NULL AND scdaycodeid > 0) AND (scperioddaycodeid IS NOT NULL AND scperioddaycodeid > 0)";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my ($billDaycodeId, $billBaseDate, $billPeriodDaycodeId, $billPeriodBaseDate, $piaFlag) = $sth->fetchrow_array();
				$sth->finish();
				
				if ($piaFlag eq "N") {
				
					print "PIA-FLG is N so Skipp\n";
					next ;
				}
				
				my $isBillingDay = isLocationOpen($runDate->getDate(), $billDaycodeId, $billBaseDate, $billPeriodDaycodeId, $billPeriodBaseDate);

				if ($isBillingDay == 0) {
						next ;
						
				}

				$sql = "SELECT /*SE024*/ type, period, sequence FROM daycode WHERE recid = '$billDaycodeId'";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my ($type, $period, $sequence) = $sth->fetchrow_array();
				$sth->finish();

				# WHEN TYPE IS "L" THEN CHANGE THE RUNDATE BACK TO THE RELATIVE DAYS FOR THE BILLINGDAYCODEID
				my $tempRunDate = '';
				if($type eq "L"){
					$tempRunDate = $runDate->getDate();
					# Finding the lagging period
					my $lag = $sequence * 7;
					$runDate->setDate($runDate->addDaysToDate($lag * -1));

				} # end of lagging period condition.

				my $endingDate;
				if($val_MANAR > 0) {
					$sql = "SELECT /*SE024*/ periodenddate FROM ".$archObj->archDB.".productpayables WHERE clientlocid = '$clientLocId' AND vendorlocid = '$customerLocId' AND type = 'I' AND source = 'S' ORDER BY periodenddate DESC LIMIT 1";
					$sth = $dbh->prepare($sql);
					$sth->execute() || die "$sql;\n";
					my ($latestPDEndDate) = $sth->fetchrow_array();
					$sth->finish();

					if(length($latestPDEndDate) == 0) {
						$endingDate = getEndingDate($period, $runDate->getDate(), $billPeriodDaycodeId, $billPeriodBaseDate);
					} else {
						$latestPDEndDate = cvt_general::DateOperation($latestPDEndDate, 1, "ADD");
						my $nextPDEndDate = getFutureEndDateFromStartDate($latestPDEndDate, $billPeriodDaycodeId, $billPeriodBaseDate);
						if($nextPDEndDate ge $runDate->getDate()) {
							$latestPDEndDate = cvt_general::DateOperation($latestPDEndDate, 1, "SUB");
							$endingDate = $latestPDEndDate;
						} else {
							$endingDate = $nextPDEndDate;
						}
					}
				} else {
					$endingDate = getEndingDate($period, $runDate->getDate(), $billPeriodDaycodeId, $billPeriodBaseDate);
					print "isBillingDay:$isBillingDay\nendingDate:$endingDate\n" if($debug);
					if ($isBillingDay =~ /-/) {
						$endingDate = $isBillingDay;
					}
				}
									
		
			print "EndingDate: $endingDate\n" if ($debug);
			if (length($endingDate) == 0) {
				#Billing date not found move to next location
				next ;
			}
		
			
						
			if (length (cvt_general::trim($customerLocId)) == 0) {
				$customerLocId = 0;
			}
			
			my $totalamount; 
			my $finalamount;
			my $ProdInvRecId;
			my $locId;		
		
				
				######FIND THE PERCENTAGE FROM THE SERVICECHARGING PRICING TABLE
				$sql = $archObj->processSQL("SELECT /*SE024*/ recid FROM productinvoice WHERE periodenddate = '$endingDate' AND invdate = '". $runDate->getDate() ."' AND source = 'T' AND clientlocid = '$clientLocId' AND customerlocid = '$customerLocId'");
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				$ProdInvRecId = ($sth->fetchrow_array())[0];
				$sth->finish();
				
				$locId =$customerLocId;
			
							
			if($ProdInvRecId > 0)
			{	
					#Task#8910 Start
					#####CONDITION TO CHECK ABOUT THE EFDT AND ENDEFFDT 
					$sql = $archObj->processSQL("SELECT /*SE024*/ billablecustpricecodeid, recid FROM servicecharge WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type = 'LI' AND effdt <= '$endingDate' AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt >= '$endingDate') GROUP BY billablecustpricecodeid ORDER BY effdt DESC ");
					print "$sql\n" if (1);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my $serviceChargeInfo = $sth->fetchall_arrayref();
					#my ($servicechargepriceid ,$servicechargeid) = $sth->fetchrow_array();
					$sth->finish();
					
					my @ServiceChargeProc = @$serviceChargeInfo;
					foreach my $SCrecord (@ServiceChargeProc) {
						
						my $servicechargepriceid = $SCrecord->[0];
						my $servicechargeid = $SCrecord->[1];
			
					
							if (length($servicechargepriceid) == 0) {
								next;
							}
							#Task#8910 End
							
							######FIND THE PERCENTAGE FROM THE SERVICECHARGEPRICING TABLE
							$sql = $archObj->processSQL("SELECT /*SE024*/ amount FROM servicechargepricing WHERE scpricecodeid = '$servicechargepriceid' AND clientlocid = '$clientLocId' ORDER BY effdt LIMIT 1");
							print "$sql\n" if ($debug);
							$sth = $dbh->prepare($sql);
							$sth->execute() or die "$sql;\n";
							my $Amount= ($sth->fetchrow_array())[0];
							$sth->finish();
							
							$finalamount = $Amount;
										
							#####FIND THE EXISTENCE OF THE RECORD IN THE TRANSACTIVITYSC TABLE
							$sql = $archObj->processSQL("SELECT /*SE024*/ COUNT(*) FROM transactivitysc WHERE locationid = '$clientLocId' AND datet = '$endingDate' AND customerlocid = '$locId' AND type = 'LI' AND servicechargeid = '$servicechargeid'"); #Task#8910
							print "$sql\n" if ($debug);
							$sth = $dbh->prepare($sql);
							$sth->execute() or die "$sql;\n";
							my $duplicate = ($sth->fetchrow_array())[0];
							$sth->finish();
							
							my $closeddatevendinv = $dtINDEF->getDate();
							my $closeddatevend = $dtINDEF->getDate();
							my $closeddatecustpay = $dtINDEF->getDate();
							print "\n\nfinalamount::$finalamount\n\n";
						if($finalamount > 0)
						{
							if ($duplicate == 0) {
								$sql = $archObj->processSQL("INSERT /*SE024*/ INTO transactivitysc (locationid, type, datet, customerlocid, specificproductid, actquantity, unitsales, unitcost, unitsalesvend, unitcostcust,  scpricecodeid, servicechargeid, closeddatevend, closeddatevendinv, closeddatecustpay) VALUES ('$clientLocId', 'LI', '$endingDate', '$locId', '0', '1', '$finalamount', '0', '0', '0', '$servicechargepriceid', '$servicechargeid', '$closeddatevend', '$closeddatevendinv', '$closeddatecustpay')");
								print "$sql\n" if ($debug);
								$dbh->do($sql) or die "$sql;\n";
							}else {
								
								#UPDATE THE transactivitysc
								$sql =$archObj->processSQL( "UPDATE /*SE024*/ transactivitysc SET unitsales = '$finalamount' , archupdt = IF(archupdt = 'P', 'U', archupdt) ,scpricecodeid ='$servicechargepriceid' , closeddatevend = '$closeddatevend', closeddatevendinv ='$closeddatevendinv', closeddatecustpay = '$closeddatecustpay' WHERE  locationid = '$clientLocId' AND datet = '$endingDate' AND customerlocid = '$locId' AND servicechargeid = '$servicechargeid'"); #Task#8910
								print "$sql\n" if ($debug);
								$dbh->do($sql) or die "$sql;\n";
								
								
							}
						}	
					}#Task#8910
			}
		}	
	print "\n-----------------------createLIServiceChargeCust Process End---------------------\n";
}
#Task#8756 End
sub createPCServiceChargeCust {
	my ($clientId, $clientLocId,$sctpc) = @_;
	
	$sql = "SELECT datevar FROM system WHERE recid = 'INDEF'";
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my $dtINDEF = date->new(($sth->fetchrow_array())[0]);
	$sth->finish();
	
	#Task#8904 Start
	$sql = "SELECT /*SE024*/ charvar FROM locationsystem WHERE recid = 'NEGSC' AND locationid = '$clientLocId'";
	$sth = $dbh->prepare($sql);
	$sth->execute() || die "$sql\n";
	my $NEGSC_char = ($sth->fetchrow_array)[0];
	$sth->finish();
	#Task#8904 End
	
	$sql = "SELECT distinct(customerlocid)  FROM servicecharge WHERE clientlocid = '$clientLocId' AND customerlocid > 0 AND type = 'PC' ";
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		my $rows = $sth->rows();
		my $refLocations = $sth->fetchall_arrayref();
		$sth->finish();

		my @custLocations = @$refLocations;
		foreach my $record (@custLocations) {
			my $customerLocId = $record->[0];
			#my $servicechargepriceid = $record->[1];
			#my $servicechargeid = $record->[2];
			
			$sql = "SELECT scdaycodeid, basescdate, scperioddaycodeid, basescperioddate, piaflag FROM routelink WHERE clientid = '$clientId' and locationid = '$customerLocId' AND (scdaycodeid IS NOT NULL AND scdaycodeid > 0) AND (scperioddaycodeid IS NOT NULL AND scperioddaycodeid > 0)";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my ($billDaycodeId, $billBaseDate, $billPeriodDaycodeId, $billPeriodBaseDate, $piaFlag) = $sth->fetchrow_array();
				$sth->finish();
				
				if ($piaFlag eq "N") {
				
					print "PIA-FLG is N so Skipp\n";
					next ;
				}
				
				my $isBillingDay = isLocationOpen($runDate->getDate(), $billDaycodeId, $billBaseDate, $billPeriodDaycodeId, $billPeriodBaseDate);

				if ($isBillingDay == 0) {
						next ;
						
				}

				$sql = "SELECT type, period, sequence FROM daycode WHERE recid = '$billDaycodeId'";
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				my ($type, $period, $sequence) = $sth->fetchrow_array();
				$sth->finish();

				# WHEN TYPE IS "L" THEN CHANGE THE RUNDATE BACK TO THE RELATIVE DAYS FOR THE BILLINGDAYCODEID
				my $tempRunDate = '';
				if($type eq "L"){
					$tempRunDate = $runDate->getDate();
					# Finding the lagging period
					my $lag = $sequence * 7;
					$runDate->setDate($runDate->addDaysToDate($lag * -1));

				} # end of lagging period condition.

				my $endingDate;
				if($val_MANAR > 0) {
					$sql = "SELECT periodenddate FROM ".$archObj->archDB.".productpayables WHERE clientlocid = '$clientLocId' AND vendorlocid = '$customerLocId' AND type = 'I' AND source = 'S' ORDER BY periodenddate DESC LIMIT 1";
					$sth = $dbh->prepare($sql);
					$sth->execute() || die "$sql;\n";
					my ($latestPDEndDate) = $sth->fetchrow_array();
					$sth->finish();

					if(length($latestPDEndDate) == 0) {
						$endingDate = getEndingDate($period, $runDate->getDate(), $billPeriodDaycodeId, $billPeriodBaseDate);
					} else {
						$latestPDEndDate = cvt_general::DateOperation($latestPDEndDate, 1, "ADD");
						my $nextPDEndDate = getFutureEndDateFromStartDate($latestPDEndDate, $billPeriodDaycodeId, $billPeriodBaseDate);
						if($nextPDEndDate ge $runDate->getDate()) {
							$latestPDEndDate = cvt_general::DateOperation($latestPDEndDate, 1, "SUB");
							$endingDate = $latestPDEndDate;
						} else {
							$endingDate = $nextPDEndDate;
						}
					}
				} else {
					$endingDate = getEndingDate($period, $runDate->getDate(), $billPeriodDaycodeId, $billPeriodBaseDate);
					print "isBillingDay:$isBillingDay\nendingDate:$endingDate\n" if($debug);
					if ($isBillingDay =~ /-/) {
						$endingDate = $isBillingDay;
					}
				}
									
		
			print "EndingDate: $endingDate\n" if ($debug);
			if (length($endingDate) == 0) {
				#Billing date not found move to next location
				next ;
			}
		
			#####CONDITION TO CHECK ABOUT THE EFDT AND ENDEFFDT 
			$sql = $archObj->processSQL("SELECT /*SE024*/ billablecustpricecodeid, recid FROM servicecharge WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type = 'PC' AND effdt <= '$endingDate' AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt >= '$endingDate')");#Task#8896
			print "$sql\n" if (1);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my ($servicechargepriceid ,$servicechargeid) = $sth->fetchrow_array();
			$sth->finish();
			if (length($servicechargepriceid) == 0) {
				next;
			}
						
			if (length (cvt_general::trim($customerLocId)) == 0) {
				$customerLocId = 0;
			}
			
			my $totalamount; 
			my $finalamount;
			my $amount;
			my $locId;		
		if($sctpc eq "Y"){
		
					$sql = "SELECT strvar FROM locationsystem WHERE recid = 'DELOC' AND locationid = '$clientLocId'";
					$sth = $dbh->prepare($sql);
					$sth->execute() || die "$sql\n";
					my $delocLoc = ($sth->fetchrow_array)[0];
					$sth->finish();
							
								
					#find the companyid 
					$sql = "SELECT companyid FROM locationlink WHERE locationid = '$customerLocId'";
					$sth = $dbh->prepare($sql);
					$sth->execute() || die "$sql\n";
					my $companyid = ($sth->fetchrow_array)[0];
					$sth->finish();
				
				
					#find the DELCO location 
					$sql = "SELECT locationid FROM locationlink ll,location l WHERE l.recid = ll.locationid AND ll.companyid = '$companyid' AND l.sdesc = '$delocLoc'";
					$sth = $dbh->prepare($sql);
					$sth->execute() || die "$sql\n";
					$locId = ($sth->fetchrow_array)[0];
					$sth->finish();
						
					#find all the locations belongs to this companyid
					$sql = "SELECT DISTINCT(locationid) FROM locationlink WHERE companyid = '$companyid'";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my $rows = $sth->rows();
					my $refcompLocations = $sth->fetchall_arrayref();
					$sth->finish();
				
					#find each location's "T" source productinvoice
					my @custcompLocations = @$refcompLocations;
					$totalamount = 0;
					foreach my $record (@custcompLocations) {
						my $locationId = $record->[0];
						
						######FIND THE PERCENTAGE FROM THE SERVICECHARGING PRICING TABLE
						$sql = $archObj->processSQL("SELECT SUM(totalamount) FROM productinvoice WHERE periodenddate = '$endingDate' AND invdate = '". $runDate->getDate() ."' AND source = 'T' AND clientlocid = '$clientLocId' AND customerlocid = '$locationId'");
						print "$sql\n" if ($debug);
						$sth = $dbh->prepare($sql);
						$sth->execute() or die "$sql;\n";
						$amount = ($sth->fetchrow_array())[0];
						$sth->finish();
						
						$totalamount = $amount + $totalamount;
						print($totalamount);
						print("\n");
						
					}
					
			}else {
				
				######FIND THE PERCENTAGE FROM THE SERVICECHARGING PRICING TABLE
				$sql = $archObj->processSQL("SELECT SUM(totalamount) FROM productinvoice WHERE periodenddate = '$endingDate' AND invdate = '". $runDate->getDate() ."' AND source = 'T' AND clientlocid = '$clientLocId' AND customerlocid = '$customerLocId'");
				print "$sql\n" if ($debug);
				$sth = $dbh->prepare($sql);
				$sth->execute() or die "$sql;\n";
				$amount = ($sth->fetchrow_array())[0];
				$sth->finish();
				$totalamount = $amount;
				$locId =$customerLocId;
			
			}				
					
			######FIND THE PERCENTAGE FROM THE SERVICECHARGEPRICING TABLE
			$sql = $archObj->processSQL("SELECT amount FROM servicechargepricing WHERE scpricecodeid = '$servicechargepriceid' AND clientlocid = '$clientLocId' ORDER BY effdt LIMIT 1");
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my $percentageAmount= ($sth->fetchrow_array())[0];
			$sth->finish();
			
			$finalamount = ($totalamount * $percentageAmount ) /100;
						
			#####FIND THE EXISTENCE OF THE RECORD IN THE TRANSACTIVITYSC TABLE
			$sql = $archObj->processSQL("SELECT COUNT(*) FROM transactivitysc WHERE locationid = '$clientLocId' AND datet = '$endingDate' AND customerlocid = '$locId' AND type = 'PC'");
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my $duplicate = ($sth->fetchrow_array())[0];
			$sth->finish();
			
			my $closeddatevendinv = $dtINDEF->getDate();
			my $closeddatevend = $dtINDEF->getDate();
			my $closeddatecustpay = $dtINDEF->getDate();
			print "\n\nfinalamount::$finalamount\n\n";
		
		#Task#8904 Start
		my $InsFlag = 0;
		if($NEGSC_char eq 'Y' && $finalamount != 0)
		{
			
			$InsFlag = 1;
			
		}elsif($NEGSC_char ne 'Y' && $finalamount > 0){
			
			$InsFlag = 1;
		}else{
			
			$InsFlag = 0;
		}
		if($InsFlag > 0)
		{
			if ($duplicate == 0) {
				$sql = $archObj->processSQL("INSERT /*SE024*/ INTO transactivitysc (locationid, type, datet, customerlocid, specificproductid, actquantity, unitsales, unitcost, unitsalesvend, unitcostcust,  scpricecodeid, servicechargeid, closeddatevend, closeddatevendinv, closeddatecustpay) VALUES ('$clientLocId', 'PC', '$endingDate', '$locId', '0', '1', '$finalamount', '0', '0', '0', '$servicechargepriceid', '$servicechargeid', '$closeddatevend', '$closeddatevendinv', '$closeddatecustpay')");
				print "$sql\n" if ($debug);
				$dbh->do($sql) or die "$sql;\n";
			}else {
				
				#UPDATE THE transactivitysc
				#$sql =$archObj->processSQL( "UPDATE transactivitysc SET unitsales = '$finalamount' , archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE  datet = '$endingDate' AND customerlocid = '$locId'");
				#print "$sql\n" if ($debug);
				#$dbh->do($sql) or die "$sql;\n";
				
				
			}
		}	
		#Task#8904 End
		}	

}

sub callLATEAfunc{
 my ($clientId,$TmpStartDate,$endingDate,$clientLocId, $customerLocId,$runDT,$maxTaRecId,$ProdList,$charvar_PPPMT,$period,$billPeriodDaycodeId, $billPeriodBaseDate,$billingFlag) = @_;
 
 print "\n\n Call LATEA Function \n\n";
 print "\n\nStartDt: $TmpStartDate ---- ENDDt:$endingDate ---- CliLocId:$clientLocId ----  CustLocId:$customerLocId  ---- RunDt:$runDT  ----  MaxTrRecid:$maxTaRecId ---- ProdList:$ProdList ---- PPPMT:$charvar_PPPMT\n\n";

	#/* Task#8394 Starts*/
	$sql = "SELECT /*se024*/ charvar FROM locationsystem WHERE locationid = '$clientLocId' AND recid = 'SUMTA' AND (endeffdt = '0000-00-00' OR endeffdt IS NULL OR endeffdt > now())";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my ($char_SUMTA) = $sth->fetchrow_array();
	$sth->finish();
	#/* Task#8394 Ends*/
 
 
 $sql = $archObj->processSQL("SELECT COUNT(*) OldCnt, SUM(IF(ta.type = 'DE' OR ta.type = 'AD', ta.actquantity * ta.unitsales, 0)) as desum, SUM(IF(ta.type = 'PU', ta.actquantity * ta.unitsales, 0)) as pusum,sp.datex,sp.recid,sp.productid FROM transactivity ta, specificproduct sp WHERE ta.recid <= '$maxTaRecId' AND ta.customerlocid = '$customerLocId' AND ta.closeddatecust = '". $runDT ."' AND ta.type IN ('DE', 'AD', 'PU') AND ta.locationid = '$clientLocId' AND ta.specificproductid = sp.recid AND sp.productid IN ($ProdList) GROUP BY sp.recid");
 print "$sql\n" if ($debug);
$sth = $dbh->prepare($sql);
$sth->execute() or die "$sql;\n";
my ($ProssLocations) = $sth->fetchall_arrayref();
#my ($OldCnt, $deAmount, $puAmount,$spDateX,$spRecid) = $sth->fetchrow_array();
$sth->finish();

			# Finding ARLAG exists or not
			$sql = "SELECT strvar FROM locationsystem WHERE recid = 'ARLAG' AND locationid = '$clientLocId' AND (endeffdt = '0000-00-00' OR endeffdt IS NULL OR endeffdt > NOW())";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my ($strvar_ARLAG) = $sth->fetchrow_array();
			$sth->finish();

			my $rows;
			my $ARLAG_val = 0;
			my %lagProdList;
			if (length($strvar_ARLAG) > 0) {

				# ARLAG record found.
				my @prodStr = split(/\|/, $strvar_ARLAG);
				print "prodStr" . "@prodStr" , "\n" if ($debug);
				my $lagWhereStr;

				
				# Building the list of product and lag from the String of ARLAG

				foreach my $rec (@prodStr) {
					my ($key, $value) = split(/~/, $rec);
					$sql = "SELECT recid FROM product WHERE sdesc = '$key' AND clientid = '$clientId' AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > NOW())";
					print "$sql\n" if ($debug);
					$sth = $dbh->prepare($sql);
					$sth->execute() or die "$sql;\n";
					my ($prodId) = $sth->fetchrow_array();
					$sth->finish();
					if (length($prodId) > 0) {
						$lagProdList{$prodId} = $value;
					}
				}
				print "lagProdList:" if ($debug);
				print %lagProdList if ($debug);
				print "\n" if ($debug);
        }else{
			$ARLAG_val = 0;
		}
my %ProdSumList;
foreach my $probLocation (@{$ProssLocations}) {
		my ($OldCnt, $deAmount, $puAmount,$spDateX,$spRecid,$spProdId) = @{$probLocation};

	print "\n\n$OldCnt, $deAmount, $puAmount,$spDateX,$spRecid,$spProdId\n\n";
	my $netAmount = $deAmount - $puAmount;
	
	
		if (not exists $lagProdList{$spProdId}) {
			$ARLAG_val = 0;
		} else {
			
			$ARLAG_val =  $lagProdList{$spProdId};
		}
		my $skedRetn = '';
		if($ARLAG_val == 0)
		{
			$sql = "SELECT skedretn  FROM standarddraw WHERE productid = '$spProdId' AND customerlocid = '$customerLocId' AND clientlocid = '$clientLocId' AND effdt <= '$endingDate'  ORDER BY effdt DESC LIMIT 1";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			($skedRetn) = $sth->fetchrow_array();
			$sth->finish();
		}
	
	my $OldSpDate = ChkendingDate($clientLocId,$customerLocId,$spDateX,$spProdId,$spRecid,$ARLAG_val,$skedRetn);
	my $OldEndDate = $endingDate;
	if($OldSpDate ge $TmpStartDate && $OldSpDate le $endingDate)
	{
		print "\n\n This is current Week Draw so Skip........\n\n\n";
		next;
	}else{
			print "\n\n This is OLD Week Draw Find EndDate........\n\n\n";
			my $prevPeriodEndDate  = $endingDate;
			my $prev_period_start_date = $TmpStartDate;
			my $NewTmpStartDate = $TmpStartDate;
			my $RunCnt = 1;
			while($RunCnt)
			{
				my $Tmp_start_date = cvt_general::DateOperation($NewTmpStartDate, 1, "SUB");
				 $prevPeriodEndDate = getEndingDate($period, $Tmp_start_date, $billPeriodDaycodeId, $billPeriodBaseDate);
				print "prevPeriodEndDate:$prevPeriodEndDate\n" if($debug);
				my $prev_period_start_date = cvt_general::DateOperation($prevPeriodEndDate, 1, "SUB");
				$prev_period_start_date = getEndingDate($period, $prev_period_start_date, $billPeriodDaycodeId, $billPeriodBaseDate);
				$prev_period_start_date = cvt_general::DateOperation($prev_period_start_date, 1, "ADD");
				print "\n\n prev_period_start_date:$prev_period_start_date<----->prevPeriodEndDate:$prevPeriodEndDate \n\n";
				if($OldSpDate ge $prev_period_start_date && $OldSpDate le $prevPeriodEndDate)
				{
						$OldEndDate = $prevPeriodEndDate;
						$RunCnt = 0;
				}else{
				
					$NewTmpStartDate = $prev_period_start_date;
					$OldEndDate = $endingDate;
					$RunCnt++;
				}
				print "\n\nRunCnt:$RunCnt\n\n";
				if($RunCnt == 300)
				{
					$RunCnt =0;
				}
			}
	}
	
	
	print "\n\n OldEndDate: $OldEndDate <  (curretn Start Date)$TmpStartDate \n\n ";
	if($OldEndDate lt $TmpStartDate && $netAmount != 0)
	{
		 
		
		 
		 $ProdSumList{$OldEndDate}{$spProdId} += $netAmount;
		 print "\n\nArray:";
		 print $ProdSumList{$OldEndDate}{$spProdId};
		 print "\n\n";
		 
	}
}
my %EndTotal ;
my $InsIdStr = '';
foreach my $TmpEndDt (sort keys %ProdSumList) {
    foreach my $TmpProdId (keys %{ $ProdSumList{$TmpEndDt} }) {
        print "$TmpEndDt, $TmpProdId: $ProdSumList{$TmpEndDt}{$TmpProdId}\n";
		
		
		if($charvar_PPPMT eq 'Y'){
		
			 $sql = "SELECT recid,billingflag  FROM productinvoice WHERE  customerlocid = '$customerLocId' AND clientlocid = '$clientLocId' AND periodenddate = '$TmpEndDt' AND type = 'I'";
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			my ($Icnt,$Oldbillingflag) = $sth->fetchrow_array();
			$sth->finish();
			if($Icnt > 0  && $ProdSumList{$TmpEndDt}{$TmpProdId} != 0)
			{
				if($billingFlag eq '' || $billingFlag eq 'P' )
				{
					$billingFlag = 'Y'
					

				}
			
			 $sql = "INSERT INTO productinvoice(clientlocid, customerlocid,productid, type, invdate, periodenddate, totalamount, billingflag, source,pmtcode) values('$clientLocId', '$customerLocId','$TmpProdId', 'C', '". $runDT ."', '$endingDate', '".($ProdSumList{$TmpEndDt}{$TmpProdId}* -1)."', '$billingFlag', 'T','O')";
			  print "$sql\n" if ($debug);
			  $dbh->do($sql) or die "$sql;\n";
			   my $productInvoiceId = $dbh->{'mysql_insertid'}; 
				if($productInvoiceId)
				{
					if($InsIdStr eq '')
					{
						$InsIdStr = $productInvoiceId;
					}else{
						$InsIdStr .= "~".$productInvoiceId;
					}
					
					#/* Task#8394 Starts*/
					if($char_SUMTA eq 'Y') {
						cvt_general::insertInvoiceTaLinkProductInvoice($dbh, $clientId, $clientLocId, $customerLocId, $TmpProdId, 'T', 'C', $endingDate, $runDT, $productInvoiceId, 'SE024');
					}
					#/* Task#8394 Ends*/
				}
				if($Oldbillingflag eq '' || $Oldbillingflag eq 'P')
				{
					
					if($Oldbillingflag eq 'P')
					{
						print "\n\nIN 'OldBillflag = P\n\n";
						print "\n\n OldbillingFlag:$Oldbillingflag\n\n";
						$sql = "UPDATE productinvoice SET billingflag = 'Y', archupdt = IF(archupdt = 'P', 'U', archupdt)  WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type IN('I','P','C') AND periodenddate = '$TmpEndDt' ";
						 print "$sql\n" if ($debug);
						 $dbh->do($sql) or die "$sql;\n";
					 }else{
					 
						print "\n\n OldbillingFlag:$Oldbillingflag\n\n";
					 }
					 $Oldbillingflag = 'Y';
				}
			
				  $sql = "INSERT INTO productinvoice(clientlocid, customerlocid, productid , type, invdate, periodenddate, totalamount, billingflag, source,pmtcode) values('$clientLocId', '$customerLocId','$TmpProdId' , 'C', '". $runDT ."', '$TmpEndDt', '".($ProdSumList{$TmpEndDt}{$TmpProdId})."', '$Oldbillingflag', 'T','O')";
				  print "$sql\n" if ($debug);
				 $dbh->do($sql) or die "$sql;\n";
				  my $productInvoiceId = $dbh->{'mysql_insertid'}; 
				if($productInvoiceId)
				{
					if($InsIdStr eq '')
					{
						$InsIdStr = $productInvoiceId;
					}else{
						$InsIdStr .= "~".$productInvoiceId;
					}
					
					#/* Task#8394 Starts*/
					if($char_SUMTA eq 'Y') {
						cvt_general::insertInvoiceTaLinkProductInvoice($dbh, $clientId, $clientLocId, $customerLocId, $TmpProdId, 'T', 'C', $TmpEndDt, $runDT, $productInvoiceId, 'SE024');
					}
					#/* Task#8394 Ends*/
				}
			 
			 
			 }else{
			 
				print "\n\nProductInvoice 'I' record not exist for periodEndDate $TmpEndDt AND productId $TmpProdId \n\n";
			 }
		}else{
			$EndTotal{$TmpEndDt} +=  $ProdSumList{$TmpEndDt}{$TmpProdId};
		}
    }
}
if($charvar_PPPMT ne 'Y'){
foreach my $TmpEndDt (sort keys %EndTotal) {
	
	print "\n\n Kay:$TmpEndDt ---TmpEndTotal:".$EndTotal{$TmpEndDt}."\n\n";
	
	 $sql = "SELECT recid,billingflag  FROM productinvoice WHERE customerlocid = '$customerLocId' AND clientlocid = '$clientLocId' AND periodenddate = '$TmpEndDt' AND type = 'I'";
	print "$sql\n" if ($debug);
	$sth = $dbh->prepare($sql);
	$sth->execute() or die "$sql;\n";
	my ($Icnt,$Oldbillingflag) = $sth->fetchrow_array();
	$sth->finish();
	if($Icnt > 0 && $ProdSumList{$TmpEndDt} != 0 )
	{
		if($billingFlag eq '')
		{
			$billingFlag = 'Y'; 
		}
		if($Oldbillingflag eq '' || $Oldbillingflag eq 'P')
		{
			
			if($Oldbillingflag eq 'P')
					{
						$sql = "UPDATE productinvoice SET billingflag = 'Y', archupdt = IF(archupdt = 'P', 'U', archupdt)  WHERE clientlocid = '$clientLocId' AND customerlocid = '$customerLocId' AND type IN('I','P','C') AND periodenddate = '$TmpEndDt' ";
						 print "$sql\n" if ($debug);
						 $dbh->do($sql) or die "$sql;\n";
					 }
			$Oldbillingflag = 'Y';
		}

		$sql = "INSERT INTO productinvoice(clientlocid, customerlocid, type, invdate, periodenddate, totalamount, billingflag, source,pmtcode) values('$clientLocId', '$customerLocId', 'C', '". $runDT ."', '$endingDate', '".($EndTotal{$TmpEndDt}* -1)."', '$billingFlag', 'T','O')";
		 print "$sql\n" if ($debug);
		 $dbh->do($sql) or die "$sql;\n";
		my $productInvoiceId = $dbh->{'mysql_insertid'}; 
				if($productInvoiceId)
				{
					if($InsIdStr eq '')
					{
						$InsIdStr = $productInvoiceId;
					}else{
						$InsIdStr .= "~".$productInvoiceId;
					}
					
					#/* Task#8394 Starts*/
					if($char_SUMTA eq 'Y') {
						cvt_general::insertInvoiceTaLinkProductInvoice($dbh, $clientId, $clientLocId, $customerLocId, '', 'T', 'C', $endingDate, $runDT, $productInvoiceId, 'SE024');
					}
					#/* Task#8394 Ends*/
				}
			 
		 
		 $sql = "INSERT INTO productinvoice(clientlocid, customerlocid,  type, invdate, periodenddate, totalamount, billingflag, source,pmtcode) values('$clientLocId', '$customerLocId', 'C', '". $runDT ."', '$TmpEndDt', '".($EndTotal{$TmpEndDt})."', '$Oldbillingflag', 'T','O')";
		 print "$sql\n" if ($debug);
		$dbh->do($sql) or die "$sql;\n";
		my $productInvoiceId = $dbh->{'mysql_insertid'}; 
				if($productInvoiceId)
				{
					if($InsIdStr eq '')
					{
						$InsIdStr = $productInvoiceId;
					}else{
						$InsIdStr .= "~".$productInvoiceId;
					}
					#/* Task#8394 Starts*/
					if($char_SUMTA eq 'Y') {
						cvt_general::insertInvoiceTaLinkProductInvoice($dbh, $clientId, $clientLocId, $customerLocId, '', 'T', 'C', $TmpEndDt, $runDT, $productInvoiceId, 'SE024');
					}
					#/* Task#8394 Ends*/
				}
	}else{
			 
				print "\n\nProductInvoice 'I' record not exist for periodEndDate $TmpEndDt \n\n";
	}
}
}

print "\n\n Return Value InsIdStr: $InsIdStr End LATEA Function \n\n";
if($InsIdStr eq '' || $InsIdStr == 0)
{
	$InsIdStr = 0;
}	
return $InsIdStr;
}
sub ChkendingDate{
	
	my($clientLocId,$customerLocId,$spDateX,$spProdId,$spRecid,$ARLAG_val,$skedRetn) = @_;
	
	#Check LEAD/LAG
	$ARLAG_val = 0;
	my $returnPdendDate = '';
	my $DateT_val = '';
	if($ARLAG_val eq 'R')
    {
		$sql = $archObj->processSQL("SELECT ta.datet FROM transactivity ta WHERE ta.locationid = '$clientLocId' AND ta.customerlocid = '$customerLocId' AND ta.type = 'SP' AND ta.specificproductid = '$spRecid'");
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		 $DateT_val = date->new(($sth->fetchrow_array())[0]);
			
		
					
					
	}elsif($ARLAG_val eq 'N')
	{
		$sql = $archObj->processSQL("SELECT sd.datex FROM specificproduct sd WHERE sd.datex > '$spDateX' AND sd.productid = '$spProdId' AND (sd.endeffdt IS NULL OR sd.endeffdt = '0000-00-00' OR sd.endeffdt > '$spDateX') ORDER BY sd.datex LIMIT 1");
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		 $DateT_val = date->new(($sth->fetchrow_array())[0]);
		
	}elsif ($ARLAG_val != 0 && $ARLAG_val ne '' )
	{
		$sql = $archObj->processSQL(" SELECT DATE_ADD('$spDateX', INTERVAL ".$ARLAG_val." DAY)");
		print "$sql\n" if ($debug);
		$sth = $dbh->prepare($sql);
		$sth->execute() or die "$sql;\n";
		$DateT_val = date->new(($sth->fetchrow_array())[0]);
	}elsif ($ARLAG_val == 0){
		#Check 'J','K'
		if($skedRetn eq 'J')
		{
			$sql = $archObj->processSQL("SELECT sd.datex FROM specificproduct sd WHERE sd.datex > '$spDateX' AND sd.productid = '$spProdId' AND (sd.endeffdt IS NULL OR sd.endeffdt = '0000-00-00' OR sd.endeffdt > '$spDateX') ORDER BY sd.datex LIMIT 1");
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			$DateT_val = date->new(($sth->fetchrow_array())[0]);
		 
		}elsif($skedRetn eq 'K')
		{
			$sql = $archObj->processSQL("SELECT sd.skedretndate FROM specificproduct sd WHERE sd.recid = '$spRecid'");
			print "$sql\n" if ($debug);
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "$sql;\n";
			$DateT_val = date->new(($sth->fetchrow_array())[0]);
		}else{
			$DateT_val = date->new($spDateX);
		}
		#Check Normal mode.
		
	}
		print "\n\n DateT_val:". $DateT_val->getDate()."\n";
		# my $desired_dow = $DateT_val->getDOWFromText($val_PDEND);            # PDEND 
		# if($desired_dow == 0)
		# {
			# $desired_dow = 7;
		# }
		# my $DateDOW = $DateT_val->getDayOfWeek();
		# if($DateDOW == 0)
		# {
			# $DateDOW = 7;
		# }
		# print "\n$desired_dow - ".$DateDOW."\n\n";
		# $DateT_val->setDate($DateT_val->addDaysToDate($desired_dow - $DateDOW)); 
		
		
		# print "\n\nNextDayOfWeek:". $DateT_val->getDate()."\n";
		# $returnPdendDate = $DateT_val->getDate();
	return $DateT_val->getDate();

}

sub createPostingTrack{

my($ClientLocId,$personid_PSTPR,$transtypecode,$PriRecid, $InvDate,$debug,$intvar_NNBAT) = @_;
my $pagecode = 'SE024';
my $tablename = 'PRI';



			
		
			
	my $sql = "Insert into postingtrack (clientlocid,personid,pagecode,transtypecode,tablename,tablerecid,transdate,batchnbr,postingdt) value($ClientLocId,$personid_PSTPR,'$pagecode','$transtypecode','$tablename',$PriRecid, '$InvDate','$intvar_NNBAT',NOW())";
	print "$sql\n" if ($debug);
	$dbh->do($sql) or die "$sql;\n";
}
#commented Task#8938 Start (this function shifed into se/cm/calculatestax.pl so that it can be call by PHP programs as well. )
#Task#8908 Start
# sub CalculateSTax{
	# #my ($dbh,$table,$field,$clientId,$clientLocId,$customerLocId,$InvoiceDate,$ProdInvRecId,$PeriodEndDt,$Source,$ClosedSource,$TypeStr,$byprogram,$ProdList) = @_;
	# my ($dbh,$clientId,$clientLocId,$customerLocId,$InvoiceDate,$ProdInvRecId,$PeriodEndDt,$Source,$ProdList) = @_;
	
		# $debug = 1;
		# print "\n----Start CalculateSTax Function ---------\n";
		# $archObj->setClient($dbh, "clientId", $clientId, "clientLocId",$clientLocId);
     
			# if (length($archObj->getArchInfo("splitSuffix")) == 0) {
				# print "No Archive Suffix found... moveing to next\n" if ($debug);
				# next;
			# }
		
		
		# $sql = "SELECT /*SE024*/ salestaxsetid FROM location WHERE recid = '$customerLocId' AND salestaxsetid IS NOT NULL AND salestaxsetid > 0";
						# print "$sql\n" if ($debug);
		# $sth = $dbh->prepare($sql);
		# $sth->execute() or die "$sql;\n";
		# my ($salesTaxSetId) = $sth->fetchrow_array();
		# $sth->finish();
	
		# if (length($salesTaxSetId) > 0) {
	
			
			# if(length($ProdList) > 0)
			# {
				# $sql = $archObj->processSQL("Select /*SE024*/  distinct(p.producttype) from product p  WHERE p.recid in ($ProdList) AND p.clientid = $clientId");
				# print "$sql\n" if ($debug);
				# $sth = $dbh->prepare($sql);
				# $sth->execute() or die "$sql;\n";
				# my $PrdTypeRec = $sth->fetchall_arrayref();
				# $sth->finish();
				
				 # foreach my $PrdTypeInfo (@{$PrdTypeRec}) 
				# {
					# my $ProdType = $PrdTypeInfo->[0];
					# my $total_SLSTX = 0;
					# $sql = "SELECT /*SE024*/ stp.percent,st.recid FROM salestaxset sts, salestaxlink stl , salestax st, salestaxpercent stp WHERE stl.effdt <= '$PeriodEndDt' AND  sts.clientid = '$clientId' AND (sts.endeffdt IS NULL OR sts.endeffdt = '0000-00-00' OR sts.endeffdt > NOW()) AND sts.recid = stl.salestaxsetid AND stl.productinvoicesource = '$Source' AND (stl.endeffdt IS NULL OR stl.endeffdt = '0000-00-00' OR stl.endeffdt > NOW()) AND stl.salestaxid = st.recid AND st.clientid = sts.clientid AND st.producttype = '$ProdType' AND (st.endeffdt IS NULL OR st.endeffdt = '0000-00-00' OR st.endeffdt > NOW())  AND st.recid = stp.salestaxid AND stp.effdt <= '$PeriodEndDt' order by stl.effdt DESC LIMIT 1";
					# print "$sql\n" if ($debug);
					# $sth = $dbh->prepare($sql);
					# $sth->execute() or die "$sql;\n";
					# my ($STPercent,$STaxId) = $sth->fetchrow_array();
					# $sth->finish();
					# if($STPercent > 0)
					# {
						
						# $sql = $archObj->processSQL("SELECT /*SE024*/ COUNT(*), SUM(IF(ta.type = 'DE' OR ta.type = 'AD', ta.actquantity * ta.unitsales, 0)) as desum, SUM(IF(ta.type = 'PU', ta.actquantity * ta.unitsales, 0)) as pusum FROM transactivity ta, specificproduct sp, product p WHERE ta.recid <= '$maxTaRecId' AND ta.customerlocid = '$customerLocId' AND ta.closeddatecust = '". $runDate->getDate() ."' AND ta.type IN ('DE', 'AD', 'PU') AND ta.locationid = '$clientLocId' AND ta.specificproductid = sp.recid AND sp.productid IN ($ProdList) AND sp.productid = p.recid AND p.clientid = $clientId AND p.producttype = '$ProdType'");
						# print "$sql\n" if ($debug);
						# $sth = $dbh->prepare($sql);
						# $sth->execute() or die "$sql;\n";
						# my ($pRows, $deAmount, $puAmount) = $sth->fetchrow_array();
						# $sth->finish();
						# print "\n $pRows, $deAmount, $puAmount \n";
						# #$deAmount = sprintf("$format",$deAmount);
						# print "\n deAmount:$deAmount \n";
		
						# #$puAmount = sprintf("$format",$puAmount);
						# print "\n puAmount:$puAmount \n";
						
						# my $totalAmountPI = $deAmount - $puAmount;
						# #$totalAmountPI = sprintf("$format",$totalAmountPI);
						# print "\n totalAmountPI:$totalAmountPI \n";
						
						# if($totalAmountPI != 0)
						# {
							# $total_SLSTX = ($totalAmountPI * $STPercent)/ 100;
							# $total_SLSTX = sprintf("$format",$total_SLSTX);
						# }
						# print "\n ($totalAmountPI * $STPercent)/ 100 : total_SLSTX:$total_SLSTX \n";
						
						# if($total_SLSTX != 0)
						# {
							# print "\n TotalTax: $total_SLSTX \n ";
								
							# $sql = $archObj->processSQL("INSERT /*SE024*/ INTO salestaxaudit(clientlocid,customerlocid,periodenddate,invdate,productinvoiceid,type,salestaxid,amount,reccreatedt) VALUES('$clientLocId','$customerLocId','$PeriodEndDt', '$InvoiceDate','$ProdInvRecId','C','$STaxId','$total_SLSTX',NOW())");
							# print "$sql\n" if ($debug);
							# $dbh->do($sql) or die "$sql;\n";
							
							# $sql = "UPDATE /*SE024*/ productinvoice SET totalamount = totalamount + $total_SLSTX,salestax = 'Y', archupdt = IF(archupdt = 'P', 'U', archupdt) WHERE recid = '$ProdInvRecId'";
							# print "$sql\n" if ($debug);
							# $dbh->do($sql) or die "$sql;\n";
							
							
							
						# }
					# }
					
					
				# }
			# }
			
			
		# }else{
			# return 0;
		# }
		
		# print "\n---- CalculateSTax Function End ---------\n";
		
				
# }
#Task#8908 End
#commented Task#8938 End
######################################################################################
# Code History :-

# 08/09/2004 :- TotalAmount is calculated for PIA customers while creating Type = D records.
# 08/10/2004 :- CustomerVacation, Holiday and CreditHold check is added before calculating the PIA Customer's total amount.
# 08/25/2004 :- TotalAmount was not calculated properly for PIA customers while creating Type = D records. It's fixed.
# 09/09/2004 :- Manual Invoice for MANCR vaiable. It will take SpecifcRotueid and process only those locations for invoice.
# 09/11/2004 :- Manual Invoice for MAMRR variable. It will normally re-process the selected client's locations for selected Invoice Date. Its a normal reprocessing.
# 09/14/2004 :- ServiceChange record is now taken from TransactivitySC table instead of Transactivity.
# 09/24/2004 :- ServiceChange record is now taken from TransactivitySC table instead of Transactivity again.
# 10/13/2004 :- Daycode.Type = "W" and period = "D" is added in isLocationOpen function to check location is open or not based on period end date logic. While checking duplicate. InvDate check is removed because that might create problem. There was a problem while calculating the PIA amount. Its fixed.
# 10/15/2004 :- AUPIA change done.
# 10/29/2004 :- While calculating amount for PIA customer, holiday check for product was not there. Its added now.
# 12/01/2004 :- VendingProblem Invoice record changed to charge only "S" type and no invoice should be created if amount is "0" and INDEF should be set if the vendingproblem record is having the zero value.
# 12/07/2004 :- Error at line 470. By mistake two "$$" was there instead of single "$".
# 01/17/2005 :- Archive changes
# 01/27/2005 :- Billingflag check is removed from the PIA case.
# 01/30/2005 :- VendingPrice.EffDt column was wrongly spelled in VendingEventMC function. Its fixed.
# 03/10/2005 :- InvDate and PayableDate changes are done. ServiceCharge.Type
# 06/14/2005 :- Product.ProductType = 'PU' check added while selecting product records.
# 08/23/2005 :- EndEffDt check removed from all the invoice creation process.
# 11/17/2005 :- In MANAR case, it was considering older periodenddate instead of new date when INVDate and PDEndDate is same. Its fixed.
# 12/03/2005 :- Transactivity and Transactivity records should be marked as INDEF after PURTA dates old when billing is not set.
# 12/10/2005 :- Invoice were not created for locations where daycode was set to more then 6 days after billing period ends. Its fixed now.
# 12/16/2005 :- Uploading to server after testing it but still "Business Days" logic needs to be implemented.
# 01/11/2006 :- PIA Invoice had a problem in calculating the amount . Its fixed.
# 01/27/2006 :- Changes related to Publisher Invoice done when creating normal I type of record.
# 02/07/2006 :- In PIA calcuation, there was a problem in AUPIA section and due to that it was not counting the data properly. Its fixed.
# 03/29/2006 :- Comment is added while creating "D" type of record for PIA case.
# 06/19/2006 :- Date class is used to possible date operations. ClientLocId added in Transactivity query to optimize the queries.
# 06/20/2006 :- Optimization is done and also removed few bugs from the script.
# 09/08/2006 :- "Business Days" logic implemented now.
# 09/12/2006 :- PIA records were not being created for Quaterly case. Its fixed.
# 11/30/2006 :- Daycode where location is open on the same day of period enddate was not working properly. Its fixed now.
# 12/02/2006 :- In case when MANAR was set, we are running the process as normal including MANAR locations. But now we will consier only MANAR locations when invoice created from "Create Invoices" link.
# 12/09/2006 :- To fix the replication problem, modified UPDATE query to not to use alise of a table name.
# 12/27/2006 :- DeliveryFee records was not being created because of one bug in condition to collect customerlocid list.
# 01/01/2007 :- Bug fixed in case if location is re-invoiced then earlier billed amount will not be accessible. Its fixed now.
# 02/09/2007 :- AUPIA problem fixed now.
# 03/20/2007 :- Copy process added after every invoice function.
# 03/26/2007 :- Client Process RunTime is implemented using ClientSystem SE024 record.
# 03/27/2007 :- MaxRecId check added before processing Transactivity record so that if records are added in between the different 3 billing then they will be ignored and will be considered into next period
# 04/02/2007 :- Please implement the new "Limit in Days Prior to Report" Late Reporting Policy.  If the related Product.ReturnsException = "D", find the related Product.ReturnsFactor and, if the SpecificProduct.DateX of the TransActivity record being processed is < today minus Product.ReturnsFactor, set all of the ClosedDateXXX values to INDEF.  For example, if the payable/receivable date is 03/28/07 and the Product.ReturnsFactor is 15 and a PU record with the SpecificProductId related SpecificProduct.DateX is  3/13, it would be given a ClosedDateXXX of 03/28/07.  But, if the SpecificProduct.DateX is  3/12, it would be given a ClosedDateXXX of 01/01/99.  the "Limit in Days Prior to Report" Late Reporting Policy should apply to ClosedDateVend and ClosedDateVendInv only.
# 05/11/2007 :- In case of MANAR, If location is reactivated after long time then it was not creating the records. Its fixed now.
# 06/12/2007 :- MySQL 5 related changes.
# 07/04/2007 :- HolidaysLink table added in Holidays check for location open case in countTotalAmount.
# 07/24/2007 :- In CustomerInvoice, StandardDraw endeffdt check was there which was cause a problem. We have also added query for deleted location so that invoice can be generaged if product is stopped delivering in between the period.
# 10/27/2007 :- Manual Service Changes to Customer was not being considered. Its fixed now.
# 12/04/2007 :- One BusinessDay logic was not properly calculating OpenDate. Its fixed now.
# 12/14/2007 :- When we start the process any client, we will store its ClientId to SE027 variable so that SE027 copy process will skip that client during that time.
# 12/19/2007 :- Transaction records UpdtFlag will be updated after creating the Invoices so that problem with copy process will be fixed. Above idea of SE027 was not used.
# 12/21/2007 :- Wholeseler PIA records will be created. AUPIA = Y case ingored here.
# 12/31/2007 :- Following is the mapping of Different Service Charge Conditions:
#				Type                 Amount Field    Date Field		Table
#				---------------------------------------------------------
#				Bill to Customer     UnitSales       ClosedDateCust     ProductInvoice
#				Pay to Customer      UnitCostCust    ClosedDateCustPay  ProductPayables
#				Bill to Publisher    UnitSalesVend   ClosedDateVendInv  ProductInvoice
#				Pay to Publisher     UnitCost        ClosedDateVend     ProductPayables
# 02/05/2008 :- The format of the ARLAG StrVar is as follows:
#			    * "Product.SDesc" ~ "Lag in days" | "Product.SDesc" ~ "Lag in days"
#			    * Example: "BW~7|SO~31"
#			    * The example indicates that the "Sports Weekly" should be included in the billing period that includes the date that is 7 days past the DateX.  For example, if the PDEND = SAT and if the DateX = 01/30/07, the "Sports Weekly" issue should be processed in the period ending 2/9/08.
#			    * Please note LocationSystem ARLAG where LocationId = 37213.
#			    * The lag will apply to Billing Period, Payable Period, and Delivery Fee period.
# 02/29/2008 :- For transaction which has UnitSalesVend = 0 OR NULL was not billed earlier. Now they are included.
# 03/05/2008 :- System.StrVar will be updated after finishing the process for RecId = SE024.
# 04/09/2008 :- Modified to skip perticular client from copyprocess during billing is going on.
# 04/11/2008 :- ARCHW record was not setup properly. It fixed now.
# 07/15/2008 :- ARLAG values "N" and "R" now included in billing.
# 07/16/2008 :- I have been noticing that the people who run this during the day (those that have a ClientSystem SE024 record)  are waiting until it's done to run some other report.
#				But there is no way to know when it is finished and they can safely proceed ahead.
#				Let's do this:  for ClientSystem = SE024 cases, when the processing is complete for a client,
#				send an email to those listed in NotifyGroup "INV".
#				(Persons related by NotifyPerson.PersonLinkId where GroupCode = "INV")
# 02/23/2009 :- "Modify the process of creation of Invoices to support the new "Variable Period" Billing Period (RouteLink.BillingPeriodDayCodeId = 400 and RouteLink.SCPeriodDayCodeId = 400 and Product.BillingPeriodDayCodeId = 400 and Product.FeePeriodDayCodeId and Product.SCPeriodDayCodeId).  With "Variable Period", no "D" invoices will be created and "I" Invoices and Payables will be created based on all un-billed transactions up to and including the base date.  This will be a "one time" process.  In other words, with other Period Day Codes, we calculate the next Billing Period End Date.  With "Variable Period" we use the Base Date for that exact date only.  We never calculate another date based on the Base Date." -- It is done.
######################################################################################
