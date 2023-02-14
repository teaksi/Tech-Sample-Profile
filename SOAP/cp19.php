<?
/*
    Version History
    ====================================

    Version.    Modi.Date       Modi.By    Description
	1.9 		2021-05-20		Chirag 	   Task#9006 => Please fix the bug we found today related to the change we had made in Task#8935 due to which CP19 was resetting/creating data on server even when client device is not a teaktrak device(Locationsystem STMCC = I/G).
														It was creating/resetting data on server even for newspaper clients.
	1.8 		2021-03-23		SBK 	   Task#8973 => As we currently test when ever device.uid is being updated, we reset the rdsend type "C" record. In the same process, We further need to test if a rdsend type "T" record exists where datastatus = "Y" exists for the device and if yes, nothing needs to be done, else, we need to create a new run data with current date/time with below records linked to the route related to device via devicelocation
	1.7 		2021-01-27		Chirag 	   Task#8945 => Please add a safety check in CP19 which should check if Incoming UDID and Device.UID both are blank and if yes, it should not update the device.UID
	1.6 		2021-01-20		Chirag 	   Task#8935 => Please modify CP19 to test if we are updating device.udid and if yes, we will also test if rdsend.datastatus = N where rdsend.type = 'C' and rdsend.deviceid = Device.Recid if yes, update rdsend.datastatus = Y.
	1.5			2020-12-31		Chirag     Task#8928 => Please modify CP19 Soap to test if locationsystem STMCC charvar = 'I' or 'G' related to device linked via devicelocation where devicelocation.locationid = locationsystem.locationid so that when device tries to connect to server and if STMCC charvar = 'I' or 'G', we will skip the UDID test where we compare the incoming device UDID with device.uid
	1.4			2020-12-03		Devarshi   Task#8900 => fix the data response format error which occurs in case when user clicks on Overview and there is no related Lat/Long data exists yet on server for the logged in route.	
    1.3         2020-11-05      Chirag     Task#8889 => We have noticed that even after the device has been deleted, it still allows the data to go incomingmsg table for the device and this results into several incomingmsg records created which would be set to "P" by SE048.

	Please modify the CP19 so that when a request comes in from device which has been deleted, it should be rejected.

	
	1.2         2020-09-30      Chirag     Task#8805 => Please modify the CP19 so that CULO transactions are processed out of regular incomingmsg/incomingxtn tables and instead data is directly processed to specificroutes or device_devicenbr table(if locationsystem TMCCL charvar = 'Y'). 
														Also, modify the function in CP19 which sends the Overview data in device using tmcpingxxx table for the specificroute requested.
	1.1         2020-05-05      NRP        Task#8575 => We need to modify CP19 which would connect to android app DP0016 and validate that its a valid device based on Device Number/Device UDID same as CP19 and then send the TMCPing data for the SpecificRoutes requested by device.
    1.0         2018-10-12      FSTPL      Task#7884 =>This comment has been added to track that changes have been made in this file to support the switch from PHP5 to PHP7

    ====================================
*/
class Cp19
{
	function setOutgoingMsg($devicenbr, $uid , $recid, $status )
	{
		 $responsestart = "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap12:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap12=\"http://www.w3.org/2003/05/soap-envelope\"><soap12:Body>";
	   $responsestart = $responsestart."<Transaction xmlns=\"http://tempuri.org/\"><RequestDocument><Transaction xmlns:xs=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns=\"\">"; 
	   $responsestop = "</Transaction></RequestDocument></Transaction>";
		 $responsestop = $responsestop."</soap12:Body></soap12:Envelope>";;
		 $soapdate = date('m/d/Y h:i:s', time());
		 $incoming_ip=$this->getClientIP();
		 $this->logMessage(":001:".$devicenbr.":".$uid.":".$incoming_ip.":setOutgoingMsg Called For " . $devicenbr . " from IP : " . $incoming_ip, 0);
		 $this->logMessage(":002:".$devicenbr.":".$uid.":".$incoming_ip.":setOutgoingMsg Called For " . $devicenbr . " Record ID : " . $recid . " And Status : " . $status, 1);
	   if ( $this->systemDown() == 1 ) 
	   {
	     $response= $responsestart."<response><responsecode>888</responsecode><responsemsg>888-System Down For Maintenance</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
	     $this->logMessage(":005:".$devicenbr.":".$uid.":".$incoming_ip.":setOutgoingMsg Called Return with 888",1);
	     return $response ;
	   }
	   $cvtconnection = $this->getDatabaseConnection();
	   if(!$cvtconnection)
	   {
	   	$response= $responsestart."<response><responsecode>889</responsecode><responsecode>889</responsecode><responsemsg>889-Failed To Connect Database</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
	    $this->logMessage(":010:".$devicenbr.":".$uid.":".$incoming_ip.":setOutgoingMsg Called Return with 889-Failed To Connect Database",1);
	    return $response ;	
	   } 	
	   $identification = $this->getDeviceIdentification($cvtconnection,$devicenbr, $uid , "O");
	 	 if ( $identification == "FAILED" )
	 	 {
	 	 	  $response= $responsestart."<response><responsecode>886</responsecode><responsemsg>886-Invalid Device Nbr/UID</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
	      $this->logMessage(":015:".$devicenbr.":".$uid.":".$incoming_ip.":setOutgoingMsg Called Return with 886 - " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
	      return $response ;		
	 	 }
	 	 
	 	 $qryGet="select count(1) as cnt from outgoingmsg where channelid = 19 AND identification='" . $identification . "' AND procflag=\"N\" AND recid = " .$recid." group by recid";
		 $rsltGet=mysqli_query( $cvtconnection, $qryGet) or die($responsestart."<response><responsecode>885</responsecode><responsemsg>885-Invalid Device Nbr/UID-" . mysqli_error($GLOBALS["___mysqli_ston"]) . "</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop);
		 if(!$rsltGet) 
		 { 
	 	  	$response= $responsestart."<response><responsecode>885</responsecode><responsemsg>885-Invalid Device Nbr/UID</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
	      $this->logMessage(":020:".$devicenbr.":".$uid.":".$incoming_ip.":setOutgoingMsg Called Return with 885 - " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
	      return $response ;				
		 }			
	   if($rowGet = mysqli_fetch_assoc($rsltGet) ) 
	   {
			  	if(!$rowGet) 
					{ 
			   	  	$response= $responsestart."<response><responsecode>883</responsecode><responsemsg>883-Invalid Device Nbr/UID</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
			        $this->logMessage(":025:".$devicenbr.":".$uid.":".$incoming_ip.":setOutgoingMsg Called Return with 880 - " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
			        return $response ;				
				  }      	
				  if ( $rowGet['cnt'] == 0 )
				  {
				  	$response= $responsestart."<response><responsecode>000</responsecode><responsemsg>000-Success Nothing To Proceed</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime><responserecordid>".$recid."</responserecordid></response>".$responsestop;
	          $this->logMessage(":030:".$devicenbr.":".$uid.":".$incoming_ip.":setOutgoingMsg Called For Return with 000 - Success Nothing To Proceed - Rec Id : " . $recid,0);
	          return $response;   
				  }
				  $deviceid=$this->getDeviceId($cvtconnection,$devicenbr, $uid);
	 	      $msg="EOTN~".trim($deviceid)."|~";
				  $qryUpd="update outgoingmsg set procflag=\"Y\" where channelid = 19 AND procflag=\"N\" AND recid <= " .$recid. " And Message = '" . $msg ."'" ;
	       	$rsltGet=mysqli_query( $cvtconnection, $qryUpd) ;
	       	if ( mysqli_affected_rows($GLOBALS["___mysqli_ston"]) >= 0 ) 
					{ 
			   	   $this->logMessage(":033:".$devicenbr.":".$uid.":".$incoming_ip.":setOutgoingMsg Called Query - " . $qryUpd ,0);
			    }  
				  
				  $qryUpd="update outgoingmsg set procflag=\"Y\" where channelid = 19 AND identification='" . $identification . "' AND procflag=\"N\" AND recid = " .$recid;
	       	$rsltGet=mysqli_query( $cvtconnection, $qryUpd) or die($responsestart."<response><responsecode>882</responsecode><responsemsg>882-Invalid Device Nbr/UID-" . mysqli_error($GLOBALS["___mysqli_ston"]) . "</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop);
		      if ( mysqli_affected_rows($GLOBALS["___mysqli_ston"]) == 0 ) 
					{ 
			   	  	$response= $responsestart."<response><responsecode>881</responsecode><responsemsg>881-Invalid Device Nbr/UID</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
			        $this->logMessage(":035:".$devicenbr.":".$uid.":".$incoming_ip.":setOutgoingMsg Called Return with 881 - " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
			        return $response ;				
				  }  
				  
				  $qryUpd="update device SET lastcommdt=now() where devicenbr = '" . $devicenbr . "'";
          $this->logMessage(":040:".$devicenbr.":".$uid.":".$incoming_ip.":setOutgoingMsg Called For " . $qryUpd ,0);
          mysqli_query( $cvtconnection, $qryUpd) ; 
				  if ( mysqli_affected_rows($GLOBALS["___mysqli_ston"]) >= 0 ) 
			   	 $this->logMessage(":045:".$devicenbr.":".$uid.":".$incoming_ip.":setOutgoingMsg Called Passed." ,0);
			   	else
			   	{ 	
						if ( mysqli_errno($GLOBALS["___mysqli_ston"]) )
						$this->logMessage(":050:".$devicenbr.":".$uid.":".$incoming_ip.":setOutgoingMsg Called Failed with " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
						else
			      $this->logMessage(":055:".$devicenbr.":".$uid.":".$incoming_ip.":setOutgoingMsg Called Passed." ,0);
			    }		  
				  
	       	$response= $responsestart."<response><responsecode>000</responsecode><responsemsg>000-Success</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime><responserecordid>".$recid."</responserecordid></response>".$responsestop;
	        $this->logMessage(":060:".$devicenbr.":".$uid.":".$incoming_ip.":setOutgoingMsg Called For Return with 000 - Rec Id : " . $recid,0);
	   }
	   else
	   {
	    	$response= $responsestart."<response><responsecode>000</responsecode><responsemsg>000-Success Nothing To Return</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
	      $this->logMessage(":065:".$devicenbr.":".$uid.":".$incoming_ip.":setOutgoingMsg Called Return with 000-Success Nothing To Return",0);
	   } 	 
	 	 return $response;   
	} //end of setOutgoingMsg
	function getOutgoingMsg($devicenbr, $uid)
	{
	
		 $responsestart = "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap12:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap12=\"http://www.w3.org/2003/05/soap-envelope\"><soap12:Body>";
	   $responsestart = $responsestart."<Transaction xmlns=\"http://tempuri.org/\"><RequestDocument><Transaction xmlns:xs=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns=\"\">"; 
	   $responsestop = "</Transaction></RequestDocument></Transaction>";
		 $responsestop = $responsestop."</soap12:Body></soap12:Envelope>";
		 $soapdate = date('m/d/Y h:i:s', time());
		 $incoming_ip=$this->getClientIP();
		 $this->logMessage(":001:".$devicenbr.":".$uid.":".$incoming_ip.":getOutgoingMsg Called For " . $devicenbr . " from IP : " . $incoming_ip , 0);
	   if ( $this->systemDown() == 1 ) 
	   {
	     $response= $responsestart."<response><responsecode>998</responsecode><responsemsg>998-System Down For Maintenance</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
	     $this->logMessage(":005:".$devicenbr.":".$uid.":".$incoming_ip.":getOutgoingMsg Called Return with 998",1);
	     return $response;
	   }
		 $cvtconnection = $this->getDatabaseConnection();
	   if(!$cvtconnection)
	   {
	   	$response= $responsestart."<response><responsecode>999</responsecode><responsemsg>999-Failed To Connect Database</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
	    $this->logMessage(":025:".$devicenbr.":".$uid.":".$incoming_ip.":getOutgoingMsg Called Return with 999-Failed To Connect Database",1);
	    return $response ;	
	   } 
	   mysqli_select_db( $cvtconnection, $db);
	 	 
	   $identification = $this->getDeviceIdentification($cvtconnection,$devicenbr, $uid , "O");
	 	 if ( $identification == "FAILED" )
	 	 {
	 	 	  $response= $responsestart."<response><responsecode>996</responsecode><responsemsg>996-Invalid Device Nbr/UID</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
	      $this->logMessage(":010:".$devicenbr.":".$uid.":".$incoming_ip.":getOutgoingMsg Called Return with 996 - " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
	      return $response;		
	 	 }   
	   
	 	 //Block 2 Start
	 	 $deviceid=$this->getDeviceId($cvtconnection,$devicenbr, $uid);
	 	 $msg="EOTN~".trim($deviceid)."|~";
	 	 
	 	 $qryGet="select recid,commnbr,message from outgoingmsg where channelid = 19 AND identification='".$identification."' AND procflag=\"N\" AND message != '".$msg."' ORDER BY prioritycode limit 1";
		 $this->logMessage(":011:".$devicenbr.":".$uid.":".$incoming_ip. ":getOutgoingMsg Called : " . $qryGet ,0);
		 $rsltGet=mysqli_query( $cvtconnection, $qryGet) or die($responsestart."<response><responsecode>995</responsecode><responsemsg>995-Invalid Device Nbr/UID-" . mysqli_error($GLOBALS["___mysqli_ston"]) . "</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop);
		 if(!$rsltGet) 
		 { 
	 	  	$response= $responsestart."<response><responsecode>995</responsecode><responsemsg>995-Invalid Device Nbr/UID</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
	      $this->logMessage(":013:".$devicenbr.":".$uid.":".$incoming_ip.":getOutgoingMsg Called Return with 995 - " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
	      return $response;				
		 }			
	   if($rowGet = mysqli_fetch_assoc($rsltGet) ) 
	   {
			  	if(!$rowGet) 
					{ 
			   	  	$response= $responsestart."<response><responsecode>994</responsecode><responsemsg>994-Invalid Device Nbr/UID</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
			        $this->logMessage(":014:".$devicenbr.":".$uid.":".$incoming_ip.":getOutgoingMsg Called Return with 994 - " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
			        return $response;				
				  }  
				  $message=$rowGet['message'];
				  $message = preg_replace('/(\r\n|\r|\n)+/', " ", $message);
				  $message = preg_replace("/[\r\n]+/", " ", $message);
				  $message = str_replace("  ", " ", $message);
				  $message = str_replace("  ", " ", $message);
				  $message = str_replace("  ", " ", $message);
				  $message = str_replace("  ", " ", $message);
				  $message = str_replace("'", " ", $message);
				  $message = str_replace("\"", " ", $message);
				  $message = base64_encode($message); 	
				  $deviceid=$this->getDeviceId($cvtconnection,$devicenbr, $uid);  
				  $this->logMessage(":017:".$devicenbr.":".$uid.":".$incoming_ip.":getOutgoingMsg device id received : " . $deviceid , 0);
				   	
				  $qryUpd = "UPDATE rdsend SET devicestatus = \"N\" WHERE deviceid='".$deviceid."' AND devicestatus='A'";	
			   	mysqli_query( $cvtconnection, $qryUpd); 
			   	if ( mysqli_affected_rows($GLOBALS["___mysqli_ston"]) >= 0 ) 
			   	 $this->logMessage(":018:".$devicenbr.":".$uid.":".$incoming_ip.":getOutgoingMsg Called Passed." ,0);
			   	else
			   	{ 	
						if ( mysqli_errno($GLOBALS["___mysqli_ston"]) )
						$this->logMessage(":018:".$devicenbr.":".$uid.":".$incoming_ip.":getOutgoingMsg Called Failed with " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
						else
			      $this->logMessage(":018:".$devicenbr.":".$uid.":".$incoming_ip.":getOutgoingMsg Called Passed." ,0);
			    }		     	
				   
				  $qryUpd="update device SET lastcommdt=now() where devicenbr = '" . $devicenbr . "'";
          $this->logMessage(":019:".$devicenbr.":".$uid.":".$incoming_ip.":getOutgoingMsg Called For " . $qryUpd ,0);
          mysqli_query( $cvtconnection, $qryUpd) ; 
				  if ( mysqli_affected_rows($GLOBALS["___mysqli_ston"]) >= 0 ) 
			   	 $this->logMessage(":019:".$devicenbr.":".$uid.":".$incoming_ip.":getOutgoingMsg Called Passed." ,0);
			   	else
			   	{ 	
						if ( mysqli_errno($GLOBALS["___mysqli_ston"]) )
						$this->logMessage(":019:".$devicenbr.":".$uid.":".$incoming_ip.":getOutgoingMsg Called Failed with " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
						else
			      $this->logMessage(":019:".$devicenbr.":".$uid.":".$incoming_ip.":getOutgoingMsg Called Passed." ,0);
			    }		    	
			    
	       	$response= $responsestart."<response><responsecode>000</responsecode><responsemsg>000-Success</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime><responserecordid>".$rowGet['recid']."</responserecordid><responsecommnbr>".$rowGet['commnbr']."</responsecommnbr><responsedata>".$message."</responsedata></response>".$responsestop;
	        $this->logMessage(":020:".$devicenbr.":".$uid.":".$incoming_ip.":getOutgoingMsg Called For Return with 000 - Rec Id : " . $rowGet['recid'],0);
			
	   }
	   else  //nothing available in outgoingmsg table so tell system to create one if available in rdsend or leave as it is
	   {
	   	    $deviceid=$this->getDeviceId($cvtconnection,$devicenbr, $uid);  
				  $this->logMessage(":021:".$devicenbr.":".$uid.":".$incoming_ip.":getOutgoingMsg device id received : " . $deviceid , 0);
				  $qryUpd="update device SET lastcommdt=now() where devicenbr = '" . $devicenbr . "'";
					$this->logMessage(":022:".$devicenbr.":".$uid.":".$incoming_ip.":getOutgoingMsg Called Query : " . $qryUpd , 0);
				  				  
			   	mysqli_query( $cvtconnection, $qryUpd); 
			   	if ( mysqli_affected_rows($GLOBALS["___mysqli_ston"]) >= 0 ) 
			   	 $this->logMessage(":023:".$devicenbr.":".$uid.":".$incoming_ip.":getOutgoingMsg Called Passed." ,0);
			   	else
			   	{ 	
						if ( mysqli_errno($GLOBALS["___mysqli_ston"]) )
						$this->logMessage(":024:".$devicenbr.":".$uid.":".$incoming_ip.":getOutgoingMsg Called Failed with " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
						else
			      $this->logMessage(":024:".$devicenbr.":".$uid.":".$incoming_ip.":getOutgoingMsg Called Passed." ,0);
			    }		     	
				 
				
				  //Trigger RDSend Process Auto Setting -Start
				  $deviceid=$this->getDeviceId($cvtconnection,$devicenbr, $uid);
				  $data = "~".$devicenbr."~";
				  $qryGet="select count(1) as cnt from rdsend where deviceid='".$deviceid."' AND datastatus = 'Y'"; 
					$rsltGet=mysqli_query( $cvtconnection, $qryGet) ;
		 
			    if($rowGet = mysqli_fetch_assoc($rsltGet) )
			    {
			  	  if ( $rowGet['cnt'] > 0 )
				    {
				   	  $this->logMessage(":024:".$devicenbr.":".$uid.":".$incoming_ip.":getOutgoingMsg Called SetIncomingMsg For data : " . $data . " And Device Id : " . $deviceid . ": In RDSend Total Records Found : " . $rowGet['cnt'] ,0);
						  $this->setIncomingMsg($devicenbr, $uid , $data , "S");
				    }
				    else
				    {
				    	$this->logMessage(":025:".$devicenbr.":".$uid.":".$incoming_ip.":getOutgoingMsg No SetIncomingMsg Called For data : " . $data . ": In RDSend Zero Records Found For Query : " . $qryGet ,0);
				    }
				    
				  }  
				  //Trigger RDSend Process Auto Auto Setting - End
				  
				     	
	    	$response= $responsestart."<response><responsecode>000</responsecode><responsemsg>000-Success Nothing To Return</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
	      $this->logMessage(":050:".$devicenbr.":".$uid.":".$incoming_ip.":getOutgoingMsg Called Return with 000-Success Nothing To Return",0);
	   }
	   //Block 2 End
	   
	   return $response;
	} //end of getOutgoingMsg
	function setIncomingMsg($devicenbr, $uid , $data , $source, $curdelay="", $curcycle="")
  {
	  
		 $responsestart = "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap12:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap12=\"http://www.w3.org/2003/05/soap-envelope\"><soap12:Body>";
	   $responsestart = $responsestart."<Transaction xmlns=\"http://tempuri.org/\"><RequestDocument><Transaction xmlns:xs=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns=\"\">"; 
	   $responsestop = "</Transaction></RequestDocument></Transaction>";
		 $responsestop = $responsestop."</soap12:Body></soap12:Envelope>";
		 $soapdate = date('m/d/Y h:i:s', time());
		 $incoming_ip=$this->getClientIP();
		 $this->logMessage(":001:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $devicenbr . " from IP : " . $incoming_ip, 0);
	   if ( $this->systemDown() == 1 ) 
	   {
	     $response= $responsestart."<response><responsecode>778</responsecode><responsemsg>778-System Down For Maintenance</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
	     $this->logMessage(":005:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called Return with 778 - System is Down",1);
	     return $response ;
	   }
	    if ( $this->isEmpty( $source ) || ( strlen(trim($source)) > 1 ) ) 
	   {
	     $response= $responsestart."<response><responsecode>777</responsecode><responsemsg>777-Empty Source Type/Invalid Data</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
	     $this->logMessage(":006:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called Return with 777 - Empty Source Type Ref. : " . $source ,1);
	     return $response ;
	   }
	   if ( trim($data) == "~" ) $data = "~".$devicenbr."~";
	   if ( $this->isEmpty( $data ) || ( strlen($data) < 3 ) ) 
	   {
	     $response= $responsestart."<response><responsecode>777</responsecode><responsemsg>777-Empty Source Type/Invalid Data</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
	     $this->logMessage(":007:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called Return with 777 - Empty Data Received. : " . $data ,1);
	     return $response ;
	   }
	   else if ( $this->endswith($data, "|~") == false && $data != "~".$devicenbr."~" )
	   {
	     $response= $responsestart."<response><responsecode>777</responsecode><responsemsg>777-Empty Source Type/Invalid Data</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
	     $this->logMessage(":008:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called Return with 777 - Data **" . $data . "** is not ended with |~",1);
	     return $response ;
	   }
	   $data = preg_replace('/(\r\n|\r|\n)+/', " ", $data);
		 $data = preg_replace("/[\r\n]+/", " ", $data);
		 $data = str_replace("&lt;" , "&#60;" , $data);
		 $data = str_replace("&gt;" , "&#62;" , $data);
		 $data = str_replace( "&#60;" , "<" , $data);
		 $data = str_replace( "&#62;" , ">" , $data);	  
		 
     
	   $cvtconnection = $this->getDatabaseConnection();
	   if(!$cvtconnection)
	   {
	   	$response= $responsestart."<response><responsecode>779</responsecode><responsemsg>779-Failed To Connect Database</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
	    $this->logMessage(":025:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called Return with 779-Failed To Connect Database",1);
	    return $response ;	
	   } 	
	   $identification = $this->getDeviceIdentification($cvtconnection,$devicenbr, $uid , "I");
	 	 if ( $identification == "FAILED" )
	 	 {
	 	 	  $response= $responsestart."<response><responsecode>776</responsecode><responsemsg>776-Invalid Device Nbr/UID</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
	      $this->logMessage(":010:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called Return with 776 - " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
	      return $response ;		
	 	 }	
    //Block 0 start
    //Logic for sleep time added on 17-Dec-2013
		 $delay=30;
		 $cycle=0;
		 $qryGet="select l.strvar as strvar from locationsystem l, devicelocation dl, device dv where l.recid='SDSCA' AND dl.deviceid = dv.recid AND dl.locationid = l.locationid  AND  dv.devicenbr = '" . $devicenbr . "'" ;
		 $this->logMessage(":0111:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $qryGet ,0);
		 $rsltGet=mysqli_query( $cvtconnection, $qryGet) or $delay=30;		
		 if($rowGet = mysqli_fetch_assoc($rsltGet) ) 
		 {
		    $transactions = $rowGet['strvar'];
			  $rowGetModeArr = explode("~",$transactions);
			  $this->logMessage(":0111:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Fast Transactions Are " . $transactions ,0);
		 } 
	
		$fastmode=0;
		foreach($rowGetModeArr as $txnVal)
		{
		 if ( strpos($data,$txnVal) !== false ) 
		 {
		 	  $this->logMessage(":0111:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Fast Transaciton Enabled For " . $txnVal ,0);
        //fast timing
        $qryGet="select l.intvar as intvar from locationsystem l, devicelocation dl, device dv where l.recid='SDSCA' AND dl.deviceid = dv.recid AND dl.locationid = l.locationid  AND  dv.devicenbr = '" . $devicenbr . "'" ;
			  $this->logMessage(":0111:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $qryGet ,0);
			  $rsltGet=mysqli_query( $cvtconnection, $qryGet) or $delay=30;		
			  if($rowGet = mysqli_fetch_assoc($rsltGet) ) 
			  {
			      $delay= $rowGet['intvar'];
			      $fastmode=1;
			  } 
			  else $delay=30;
			  $this->logMessage(":0111:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Gets Delay For SDSCA : " . $delay ,0);
			  
			  //num of cycle
			  $qryGet="select l.intvar as intvar from locationsystem l, devicelocation dl, device dv where l.recid='SDSCL' AND dl.deviceid = dv.recid AND dl.locationid = l.locationid  AND  dv.devicenbr = '" . $devicenbr . "'" ;
			  $this->logMessage(":0111:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $qryGet ,0);
			  $rsltGet=mysqli_query( $cvtconnection, $qryGet) or $cycle=150;		
			  if($rowGet = mysqli_fetch_assoc($rsltGet) ) 
			  {
			      $cycle= $rowGet['intvar'];
			  } 
			  else $cycle=150;
			  $this->logMessage(":0111:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Gets Cycle For SDSCL : " . $cycle ,0);
			  $this->logMessage(":0111:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Leaving Loop Because Fast Transaction Found Enabled : " . $delay . " and " . $cycle ,0);
			  break;
     } //end of strpos
     else
     {
     	  $this->logMessage(":0112:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Normal Transaciton Enabled For " . $txnVal ,0);
     	  //Normal timing
     	  $qryGet="select l.strvar as strvar from locationsystem l, devicelocation dl, device dv where l.recid='SDSCH' AND dl.deviceid = dv.recid AND dl.locationid = l.locationid  AND  dv.devicenbr = '" . $devicenbr . "'" ;
			  $this->logMessage(":0112:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $qryGet ,0);
			  $rsltGet=mysqli_query( $cvtconnection, $qryGet) or $delay=30;		
			  if($rowGet = mysqli_fetch_assoc($rsltGet) ) 
			  {
			      $tzvalues= $rowGet['strvar'];
			      $this->logMessage(":0112:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Time Zoned Value Get =  " . $tzvalues ,0);
			      $tzvalues_array=explode(';',$tzvalues);
			      $sql = "Create Temporary Table IF NOT EXISTS tmp_tz ( intvar int(3) , stime time not null, etime time not null, KEY idx (stime, etime) )";
            $this->logMessage(":0112:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $sql ,0);
			      mysqli_query($cvtconnection, $sql);
			      foreach($tzvalues_array as $tzvalue)
			      {
							$tzv_array=explode('-',$tzvalue);
							$this->logMessage(":0113:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Time Zone Value Get First Time = " . $tzvalue ,0);
						  $sql = "Insert into tmp_tz values ( '" . $tzv_array[0] . "','" . $tzv_array[1] . "','" .  $tzv_array[2] . "')";
						  mysqli_query($cvtconnection, $sql);	
						  $this->logMessage(":0113:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Time Zone Value Get = " . $tzv_array[0] . "," . $tzv_array[1] . "," . $tzv_array[2] ,0);
						}
				    $qryGet="Select intvar From tmp_tz where curtime() BETWEEN stime AND etime" ;
			      $this->logMessage(":0115:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $qryGet ,0);
			 		  $rsltGet=mysqli_query( $cvtconnection, $qryGet) or $delay=30;		
					  if($rowGet = mysqli_fetch_assoc($rsltGet) ) 
					  {
					  	$delay= $rowGet['intvar'];
					  }
			  } //end of if 
			  else $delay=30;
			  $this->logMessage(":0112:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Gets Delay For SDSCH : " . $delay ,0);
			  
			  //num of cycle
			  $qryGet="select l.intvar as intvar from locationsystem l, devicelocation dl, device dv where l.recid='SDSCL' AND dl.deviceid = dv.recid AND dl.locationid = l.locationid  AND  dv.devicenbr = '" . $devicenbr . "'" ;
			  $this->logMessage(":0112:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $qryGet ,0);
			  $rsltGet=mysqli_query( $cvtconnection, $qryGet) or $cycle=0;		
			  if($rowGet = mysqli_fetch_assoc($rsltGet) ) 
			  {
			      $cycle= $rowGet['intvar'];
			  } 
			  else $cycle=0;
			  $this->logMessage(":0112:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Gets Cycle For SDSCL : " . $cycle ,0);
			  
			  
     }
		} //end of while(list($key, $txnVal)
     
    //Block 0 stop
    	
	  //Block 1 Start
	  $qryGet="select recid from channelindex where channelid=19 AND email='". $devicenbr ."'";
	  $this->logMessage(":0425:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $qryGet ,0);
	  $rsltGet=mysqli_query( $cvtconnection, $qryGet) or die($responsestart."<response><responsecode>766</responsecode><responsemsg>766-Invalid Device Nbr/UID-" . mysqli_error($GLOBALS["___mysqli_ston"]) . "</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop);
		if(!$rsltGet) 
		{ 
	 	  	$response= $responsestart."<response><responsecode>765</responsecode><responsemsg>765-Invalid Device Nbr/UID</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
	      $this->logMessage(":0131:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called Return with 765 - " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
	      return $response ;				
		}			
	  if($rowGet = mysqli_fetch_assoc($rsltGet)) 
	  {
	      $channelsession= $rowGet['recid'];
	  } 
	  else
	  {
				  $qryUpd="start transaction";
				  $this->logMessage(":031:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $qryUpd ,0);
			    mysqli_query( $cvtconnection, $qryUpd) or die($responsestart."<response><responsecode>772</responsecode><responsemsg>772-Invalid Device Nbr/UID-" . mysqli_error($GLOBALS["___mysqli_ston"]) . "</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop);
			    
			    
			    $qryUpd="update system set intvar=intvar+1 where recid = 'CHN19'";
			    $this->logMessage(":032:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $qryUpd ,0);
			    mysqli_query( $cvtconnection, $qryUpd) or die($responsestart."<response><responsecode>770</responsecode><responsemsg>770-Invalid Device Nbr/UID-" . mysqli_error($GLOBALS["___mysqli_ston"]) . "</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop);
			   
			   	 
			    $qryGet="select intvar from system where recid =\"CHN19\"";
				  $this->logMessage(":033:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $qryGet ,0);
				  $rsltGet=mysqli_query( $cvtconnection, $qryGet) or die($responsestart."<response><responsecode>769</responsecode><responsemsg>769-Invalid Device Nbr/UID-" . mysqli_error($GLOBALS["___mysqli_ston"]) . "</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop);
					if(!$rsltGet) 
					{ 
				 	  	$response= $responsestart."<response><responsecode>769</responsecode><responsemsg>769-Invalid Device Nbr/UID</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
				      $this->logMessage(":013:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called Return with 769 - " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
				      return $response ;				
					}			
				  if($rowGet = mysqli_fetch_assoc($rsltGet) ) 
				  {
				      $channelsession= $rowGet['intvar'];
				  }
				  
				  $qryGet="commit";
				  $this->logMessage(":034:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $qryGet ,0);
				  mysqli_query( $cvtconnection, $qryGet) or die($responsestart."<response><responsecode>768</responsecode><responsemsg>768-Invalid Device Nbr/UID-" . mysqli_error($GLOBALS["___mysqli_ston"]) . "</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop);
					
					$qryIns="insert INTO channelindex (channelid,channelsession,email) VALUES (19,'" . $channelsession . "','".$devicenbr."')";
			    $this->logMessage(":035:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $qryIns ,0);
			    mysqli_query( $cvtconnection, $qryIns) or die($responsestart."<response><responsecode>767</responsecode><responsemsg>767-Invalid Device Nbr/UID-" . mysqli_error($GLOBALS["___mysqli_ston"]) . "</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop);
					
					$qryGet="select recid from channelindex where channelid=19 AND email='". $devicenbr ."' AND channelsession=" . $channelsession;
				  $this->logMessage(":045:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $qryGet ,0);
				  $rsltGet=mysqli_query( $cvtconnection, $qryGet) or die($responsestart."<response><responsecode>766</responsecode><responsemsg>766-Invalid Device Nbr/UID-" . mysqli_error($GLOBALS["___mysqli_ston"]) . "</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop);
					if(!$rsltGet) 
					{ 
				 	  	$response= $responsestart."<response><responsecode>765</responsecode><responsemsg>765-Invalid Device Nbr/UID</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
				      $this->logMessage(":013:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called Return with 765 - " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
				      return $response ;				
					}			
				  if($rowGet = mysqli_fetch_assoc($rsltGet) ) 
				  {
				      $channelsession= $rowGet['recid'];
				  } 
	  }
	  //Block 1 Ends
	  
	  
    //delay and cycle fields are added
    $qryUpd="update device SET lastcommdt=now() , delay = '" .$curdelay."',cycle='".$curcycle."' where devicenbr = '" . $devicenbr . "'";
    $this->logMessage(":0311:".$devicenbr.":".$uid.":".$incoming_ip."data:$data:setIncomingMsg Called For " . $qryUpd ,0);//Task#8805
    mysqli_query( $cvtconnection, $qryUpd) or die($responsestart."<response><responsecode>770</responsecode><responsemsg>770-Invalid Device Nbr/UID-" . mysqli_error($GLOBALS["___mysqli_ston"]) . "</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop);
    
    
	  
	  //Block 2 Start
	  if( strlen($data) == 8) 
		{
				$data = "~".$data."~";
		}
		
	//Task#8805	 Start
	$qryGet="select /*CP19*/ cl.strvar as str_SPLIT, dl.locationid ClientLocId from clientsystem cl, devicelocation dl, device dv where cl.recid='SPLIT' AND dl.deviceid = dv.recid AND dl.companyid = cl.clientid  AND  dv.devicenbr = '" . $devicenbr . "'" ;
	$this->logMessage(":0111:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $qryGet ,0);
	$rsltGet=mysqli_query( $cvtconnection, $qryGet) or $cycle=150;		
	if($rowGet = mysqli_fetch_assoc($rsltGet) ) 
	{
		 $str_SPLIT= $rowGet['str_SPLIT'];
		 $ClientLocId= $rowGet['ClientLocId'];
	} 		
	
	$qryGet="select /*CP19*/ charvar FROM locationsystem where recid='TMCCL' AND locationid = $ClientLocId AND (endeffdt IS NULL || endeffdt > NOW() || endeffdt = '0000-00-00')"  ;
	 $this->logMessage(":0111:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $qryGet ,0);
	 $rsltGet=mysqli_query( $cvtconnection, $qryGet) or $cycle=150;		
	 if($rowGet = mysqli_fetch_assoc($rsltGet) ) 
	 {
	     $chr_TMCCL= $rowGet['charvar'];
		  
	 } 	
	 if(stristr($data,"CULO~") && $chr_TMCCL == 'Y' )
	 {
		
		$explodeData = explode("|",$data);
		 $insData = '';
		 foreach($explodeData as $newData)
		 {
			if(strlen($newData) > 1)
			{		
				if($insData)
					$insData .= ",('$ClientLocId','$newData')";
				 else
					$insData = "('$ClientLocId','$newData')"; 
			}
		 }
		 if($insData)
		 {
			  $qryIns="insert /*CP19*/ INTO cvtp0001.device_$devicenbr (clientlocid,rawdata) VALUES $insData;";
				$this->logMessage(":055:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $qryIns ,0);
				mysqli_query( $cvtconnection, $qryIns) or die($responsestart."<response><responsecode>764</responsecode><responsemsg>764-Invalid Device Nbr/UID-" . mysqli_error($GLOBALS["___mysqli_ston"]) . "</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop);
				$ins_recid = mysqli_insert_id($cvtconnection);
		 }
	 }else{
	//Task#8805 End
    $qryIns="insert INTO incomingmsg (commnbr,reccreatets,channelid,channelsession,procflag,identification,prioritycode,message,userip,source) VALUES (0 ,now(),19,'" . $channelsession . "','N','" . $identification ."',2,'" . $data . "','" . $incoming_ip . "','" . $source . "')";
    $this->logMessage(":055:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $qryIns ,0);
    mysqli_query( $cvtconnection, $qryIns) or die($responsestart."<response><responsecode>764</responsecode><responsemsg>764-Invalid Device Nbr/UID-" . mysqli_error($GLOBALS["___mysqli_ston"]) . "</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop);
		
		$qryGet="select Max(recid) as m_recid from incomingmsg where commnbr = 0 AND identification = '" . $identification . "' AND userip = '" . $incoming_ip . "'";
		$this->logMessage(":065:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $qryGet ,0);
	  $rsltGet=mysqli_query( $cvtconnection, $qryGet) or die($responsestart."<response><responsecode>763</responsecode><responsemsg>763-Invalid Device Nbr/UID-" . mysqli_error($GLOBALS["___mysqli_ston"]) . "</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop);
		if(!$rsltGet) 
		{ 
	 	  	$response= $responsestart."<response><responsecode>762</responsecode><responsemsg>762-Invalid Device Nbr/UID</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
	      $this->logMessage(":065:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called Return with 761 - " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
	      return $response ;				
		}			
	  if($rowGet = mysqli_fetch_assoc($rsltGet) ) 
	  {
	      $ins_recid= $rowGet['m_recid'];
	  } 
	  //Block 2 End
	  
	  
	  //Block 3 Start 
		$qryUpd="start transaction";
	  $this->logMessage(":071:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $qryUpd ,0);
    mysqli_query( $cvtconnection, $qryUpd) or die($responsestart."<response><responsecode>760</responsecode><responsemsg>760-Invalid Device Nbr/UID-" . mysqli_error($GLOBALS["___mysqli_ston"]) . "</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop);
    
    
    
   	$commnbr=0; 
    $qryGet="select intvar from system where recid ='NNCPR'";
	  $this->logMessage(":075:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $qryGet ,0);
	  $rsltGet=mysqli_query( $cvtconnection, $qryGet) or die($responsestart."<response><responsecode>758</responsecode><responsemsg>758-Invalid Device Nbr/UID-" . mysqli_error($GLOBALS["___mysqli_ston"]) . "</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop);
		if(!$rsltGet) 
		{ 
	 	  	$response= $responsestart."<response><responsecode>785</responsecode><responsemsg>785-Invalid Device Nbr/UID</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop;
	      $this->logMessage(":075:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called Return with 758 - " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
	      return $response ;				
		}			
	  if($rowGet = mysqli_fetch_assoc($rsltGet) ) 
	  {
	      $commnbr=$rowGet['intvar'];
	  }
	  
	  $qryUpd="update system set intvar=intvar+1 where recid = 'NNCPR'";
      $this->logMessage(":072:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $qryUpd ,0);
   	  mysqli_query( $cvtconnection, $qryUpd) or die($responsestart."<response><responsecode>759</responsecode><responsemsg>759-Invalid Device Nbr/UID-" . mysqli_error($GLOBALS["___mysqli_ston"]) . "</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop);
	  
	  $qryUpd="update incomingmsg set commnbr = " . $commnbr . " where recid = " . $ins_recid . " And commnbr = 0";
    $this->logMessage(":076:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $qryUpd ,0);
   	mysqli_query( $cvtconnection, $qryUpd) or die($responsestart."<response><responsecode>757</responsecode><responsemsg>757-Invalid Device Nbr/UID-" . mysqli_error($GLOBALS["___mysqli_ston"]) . "</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop);
    
	  
	  $qryGet="commit";
	  $this->logMessage(":080:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For " . $qryGet ,0);
	  mysqli_query( $cvtconnection, $qryGet) or die($responsestart."<response><responsecode>756</responsecode><responsemsg>756-Invalid Device Nbr/UID-" . mysqli_error($GLOBALS["___mysqli_ston"]) . "</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime></response>".$responsestop);
		//Block 3 End
	 }//Task#8805
		 
		
		$response= $responsestart."<response><responsecode>000</responsecode><responsemsg>000-Success</responsemsg><responsedeviceid>".$devicenbr."</responsedeviceid><responsedeviceuid>".$uid."</responsedeviceuid><responsedatetime>".$soapdate."</responsedatetime><responserecordid>".$ins_recid."</responserecordid><responsecommnbr>".$commnbr."</responsecommnbr><responsedelay>".$delay."</responsedelay><responsecycle>".$cycle."</responsecycle><responsefastmode>".$fastmode."</responsefastmode></response>".$responsestop;
    $this->logMessage(":085:".$devicenbr.":".$uid.":".$incoming_ip.":setIncomingMsg Called For Return with 000 - New Rec Id : " . $ins_recid,0);
	 
	  return $response;   
  } //end of setIncomingMsg

	/*Task#8575 Starts */
	function getTmcPing($devicenbr, $uid , $route){
	$incoming_ip=$this->getClientIP();
	$this->logMessage(":001:".$devicenbr.":".$uid.":".$route.":".$incoming_ip.":getTmcPing Called For " . $devicenbr . " from IP : " . $incoming_ip , 0);
	
	if ($this->systemDown() == 1) {	
	//$response = '{"deviceNumber": '.$devicenbr.',"SpecificRoute": '.$route.',"responseCode": 998}';//Commented#8900
	$response = '{"deviceNumber": '.$devicenbr.',"SpecificRoute":"'.$route.'","responseCode": 998}';//Task#8900
	$this->logMessage(":005:".$devicenbr.":".$uid.":".$route.":".$incoming_ip.":getTmcPing Called Return with 998 - System Down For Maintenance",1);
	return $response;
    }
	
	$cvtconnection = $this->getDatabaseConnection();
	if (!$cvtconnection) {
	//$response = '{"deviceNumber": '.$devicenbr.',"SpecificRoute": '.$route.',"responseCode": 999}';//Commented#8900
	$response = '{"deviceNumber": '.$devicenbr.',"SpecificRoute": "'.$route.'","responseCode": 999}';//Task#8900
	$this->logMessage(":025:".$devicenbr.":".$uid.":".$route.":".$incoming_ip.":getTmcPing Called Return with 999 - Failed To Connect Database",1);
	return $response;
	}
	
	mysqli_select_db( $cvtconnection, $db);
	$identification = $this->getDeviceIdentification($cvtconnection, $devicenbr, $uid, "O");

	if ($identification == "FAILED") {
	//$response = '{"deviceNumber": '.$devicenbr.',"SpecificRoute": '.$route.',"responseCode": 996}';//Commented#8900
	$response = '{"deviceNumber": '.$devicenbr.',"SpecificRoute": "'.$route.'","responseCode": 996}';//Task#8900
	$this->logMessage(":010:".$devicenbr.":".$uid.":".$route.":".$incoming_ip.":getTmcPing Called Return with 996 - Failed To Device Identification" ,1);
	return $response;
	}
	
	$locationId = $this->getLocationId($cvtconnection, $devicenbr, $uid, $route );
	if ($locationId == "FAILED") {
	//$response = '{"deviceNumber": '.$devicenbr.',"SpecificRoute": '.$route.',"responseCode": 800}';//Commented#8900
	$response = '{"deviceNumber": '.$devicenbr.',"SpecificRoute": "'.$route.'","responseCode": 800}';//Task#8900
	$this->logMessage(":015:".$devicenbr.":".$uid.":".$route.":".$incoming_ip.":getTmcPing Called Return with 800 - Failed To Get Device Location"  ,1);
	return $response;
	}
	
	$routeArr = explode("_", $route);
	$routenbr = $routeArr[0];
	$dateAsked = "20" . substr($routeArr[1], 4, 2) . "-" . substr($routeArr[1], 0, 2) . "-" . substr($routeArr[1], 2, 2);
	$timeAsked = $routeArr[2] . ':00';
	
	
	$split0=$this->getSplit($cvtconnection, $locationId,$devicenbr, $uid, $route);
	if ($split0 == "FAILED") {
	    //$response = '{"deviceNumber": '.$devicenbr.',"SpecificRoute": '.$route.',"responseCode": 800}';//Commented#8900
	    $response = '{"deviceNumber": '.$devicenbr.',"SpecificRoute": "'.$route.'","responseCode": 800}';//Task#8900
	    $this->logMessage(":015:".$devicenbr.":".$uid.":".$route.":".$incoming_ip.":getTmcPing Called Return with 800 - Failed To Split Table",1);
	    return $response;
	}
	
	$specificroutesId = $this->getSpecificRouteId($cvtconnection, $devicenbr, $uid, $route, $locationId,$split0, $dateAsked, $timeAsked,$routenbr);
	if ($specificroutesId == "FAILED") {
	    //$response = '{"deviceNumber": '.$devicenbr.',"SpecificRoute": '.$route.',"responseCode": 800}';//Commented#8900
	    $response = '{"deviceNumber": '.$devicenbr.',"SpecificRoute": "'.$route.'","responseCode": 800}';//Task#8900
	    $this->logMessage(":020:".$devicenbr.":".$uid.":".$route.":".$incoming_ip.":getTmcPing Called Return with 800 - Failed To Get SpecificRoute" ,1);
	    return $response;
	}
	$rsltGet = $this->getTmc($locationId, $cvtconnection, $specificroutesId,$devicenbr, $uid, $route, $split0); //Task#8805
	if(!$rsltGet) 
    { 
	    //$response = '{"deviceNumber": '.$devicenbr.',"SpecificRoute": '.$route.',"responseCode": 800}';//Commented#8900
	    $response = '{"deviceNumber": '.$devicenbr.',"SpecificRoute": "'.$route.'","responseCode": 800}';//Task#8900
	    $this->logMessage(":025:".$devicenbr.":".$uid.":".$route.":".$incoming_ip.":getTmcPing Called Return with 800 - Failed To Get TMC" ,1);
	    return $response;
	}
	else{
	$num_row = mysqli_num_rows($rsltGet);
    if($num_row > 0)
	{			
		          
		$count=1;
		$response = '{"deviceNumber": '.$devicenbr.',"SpecificRoute": "'.$route.'","responseCode": 200,"latLongs": [';
	    $responseIn = '';
		while ($rowGet = mysqli_fetch_assoc($rsltGet))
		{
		  if($num_row == $count)
		  $responseIn .= '{ "latlng": "'.$rowGet['latitude'].'|'.$rowGet['longitude'].'","index": '.$count.'}';	
		  else
		  $responseIn .= '{ "latlng": "'.$rowGet['latitude'].'|'.$rowGet['longitude'].'","index": '.$count.'},';	
		  $count++; 
		} 
        $response .= $responseIn;		
		$response .= ']}';
        $this->logMessage(":030:".$devicenbr.":".$uid.":".$route.":".$incoming_ip.":getTmcPing Called  Return with 200 - Success",0);
		return $response; 
			
	}
	else{
		//$response = '{"deviceNumber": '.$devicenbr.',"SpecificRoute": '.$route.',"responseCode": 800}';//Commented#8900
		$response = '{"deviceNumber": '.$devicenbr.',"SpecificRoute": "'.$route.'","responseCode": 800}';//Task#8900
	    $this->logMessage(":035:".$devicenbr.":".$uid.":".$route.":".$incoming_ip.":getTmcPing Called Return with 800 - Failed To Get TMC" ,1);
	    return $response;
	}
		 
	}
	
   }
  
   function getSpecificRouteId($cvtconnection, $devicenbr, $uid, $route, $locationid,$split0, $dateAsked, $timeAsked,$routenbr) {
   
   $query = "SELECT /*cp19*/ recid FROM route WHERE locationid = '$locationid' AND routenbr = '$routenbr' AND (endeffdt = '0000-00-00' OR endeffdt IS NULL OR endeffdt > NOW())";
   $this->logMessage(":500:".$devicenbr.":".$uid.":".$route.":".$incoming_ip.":getSpecificRouteId() Called For " . $locationid. "," .$routenbr  ,0);
   
   $rsltGet=mysqli_query( $cvtconnection, $query) ;
   if(!$rsltGet) 
   { 
	 $this->logMessage(":505:".$deviceid.":".$uid.":".$route.":".$incoming_ip.":getSpecificRouteId() Called Return with 296 - " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
	 return "FAILED";
   }
   if ($rowGet = mysqli_fetch_assoc($rsltGet))
   {
	  $routeId= $rowGet['recid'];
   }
   else
   {
	  $this->logMessage(":510:".$devicenbr.":".$uid.":".$route.":".$incoming_ip.":getSpecificRouteId() Called Return with 800",1);
	  return "FAILED" ;
   }
   
   $query = "SELECT /*cp19*/ recid FROM specificroutes".$split0."  WHERE dispatchlocid = '$locationid' AND datesked = '$dateAsked' AND timesked = '$timeAsked' AND routeid = '$routeId'";
   $this->logMessage(":520:".$devicenbr.":".$uid.":".$route.":".$incoming_ip.":getSpecificRouteId() Called For " . $routeId  ,0);
   
   $rsltGet=mysqli_query( $cvtconnection, $query) ;
   if(!$rsltGet)
   { 
	 $this->logMessage(":525:".$deviceid.":".$uid.":".$route.":".$incoming_ip.":getSpecificRouteId() Called Return with 296 - " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
	 return "FAILED";
   }
   if ($rowGet = mysqli_fetch_assoc($rsltGet))
   {
	  $specificroutesId= $rowGet['recid'];
	  return $specificroutesId;
   }
   else
   {
	  $this->logMessage(":530:".$devicenbr.":".$uid.":".$route.":".$incoming_ip.":getSpecificRouteId() Called Return with 800",1);
	  return "FAILED" ;
   }
}
   function getTmc($locationId, $cvtconnection, $specificroutesId,$devicenbr, $uid, $route, $str_SPLIT) { //Task#8805


	$curDate = date("Y-m-d");
	$query = "SELECT /*cp19*/ latitude, longitude
		      FROM cvtp0001.tmcping$str_SPLIT
		      WHERE  clientlocid = '$locationId' 
			  AND specificrouteid = '$specificroutesId'
		      ORDER BY recid ASC"; //Task#8805
	
	$rsltGet=mysqli_query( $cvtconnection, $query) ;
	$this->logMessage(":600:".$devicenbr.":".$uid.":".$route.":".$incoming_ip.":getTmc() Called For " . $locationId .",". $specificroutesId ,0);
   
    return $rsltGet;	
	}
   
   function getLocationId($cvtconnection, $devicenbr, $uid, $route ) {
   
   $query = "SELECT /*cp19*/ dl.locationid
             FROM   devicelocation dl,device d
             WHERE  d.devicenbr='$devicenbr'
             AND d.recid=dl.deviceid
             AND (dl.endeffdt = '0000-00-00' OR dl.endeffdt IS NULL OR dl.endeffdt > NOW())";

   $this->logMessage(":300:".$devicenbr.":".$uid.":".$route.":".$incoming_ip.":getLocationId() Called For " . $devicenbr  ,0);
   $rsltGet=mysqli_query( $cvtconnection, $query) ;
   if(!$rsltGet) 
   { 
	 $this->logMessage(":305:".$deviceid.":".$uid.":".$route.":".$incoming_ip.":getLocationId() Called Return with 296 - " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
	 return "FAILED";
   }
   if ($rowGet = mysqli_fetch_assoc($rsltGet))
   {
	  $locationId= $rowGet['locationid'];
	  return $locationId;
   }
   else
   {
	  $this->logMessage(":310:".$devicenbr.":".$uid.":".$route.":".$incoming_ip.":getLocationId() Called Return with 800",1);
	  return "FAILED" ;
   }	
   
   }
   
   function getSplit($cvtconnection, $locationid,$devicenbr, $uid, $route){
	
	$query="SELECT /*cp19*/ cs.strvar
	        FROM locationlink ll,clientsystem cs
	        WHERE ll.`locationid` = '$locationid'
		    AND ll.companyid=cs.clientid
		    AND cs.recid='SPLIT'";
	$this->logMessage(":400:".$devicenbr.":".$uid.":".$route.":".$incoming_ip.":getSplit() Called For " . $locationid  ,0);
   	$rsltGet=mysqli_query( $cvtconnection, $query) ;
	if(!$rsltGet) 
    { 
	 $this->logMessage(":405:".$deviceid.":".$uid.":".$route.":".$incoming_ip.":getSplit() Called Return with 296 - " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
	 return "FAILED";
    }
	if ($rowGet = mysqli_fetch_assoc($rsltGet))
	{
		$split0= $rowGet['strvar'];
		return $split0;
    }
	else
    {
	  $this->logMessage(":410:".$devicenbr.":".$uid.":".$route.":".$incoming_ip.":getSplit() Called Return with 800",1);
	  return "FAILED" ;
    }
	
	}

  /*Task#8575 Ends */
	
	function systemDown()
	{
		$fptr = fopen("../sys_status.txt","r");
		$downFlag = 0;
		while(!feof($fptr)) {
		        $line = fgets($fptr, 255);
		        if(strstr(strtoupper($line),"SYSTEM_STATUS") && strstr(strtoupper($line), "DOWN")) {
		                $downFlag = 1;
		                break;
		        }
		}
		fclose($fptr);
	  return $downFlag;
	} //end of systemDown
	
	function logMessage($message, $err)
	{
	  if ( $err ) error_log ( ":CP19:Error:".$message );
	  else error_log ( ":CP19:Message:".$message );
	} //end of logMessage
	function getDatabaseDetails($strDb) 
	{
	
		$strFilePath = "/usr/local/apache/htdocs/twce/soap/cp19.con";
	    $arrFinalInfo = $this->getConfigDetail($strFilePath);
	
	    $strUserName = $arrFinalInfo['user'];
	    $strPassword = $arrFinalInfo['pass'];
		$strServer = $arrFinalInfo['server'];
		$strPort = $arrFinalInfo['port']; //Task#8575
	
		$returnArr['strUserName'] = $strUserName;
		$returnArr['strPassword'] = $strPassword;
		$returnArr['strServer'] = $strServer; 
		$returnArr['strPort'] = $strPort; //Task#8575
	
		return $returnArr;
	} //end of getDatabaseDetails
	function getConfigDetail($strFileName)
	{
	
		$returnArr = array();
	  $fileArr = file($strFileName);
		for($cntId = 0; $cntId < count($fileArr); $cntId++) 
		{
	 	      if(substr($fileArr[$cntId], 0, 1) == "#") 
	      	{
				   continue;
		     	}
	        else 
	        {
	        	// TRUNCATE from FIRST = SIGN
	            $equalPos = strpos($fileArr[$cntId], "=");
	
	            $strKey = substr($fileArr[$cntId], 0, $equalPos);
	            $strValue = substr($fileArr[$cntId], $equalPos + 1);
	
	            // TRIM EXTRA SPACES
	            $strKey = trim($strKey);
	            $strValue = trim($strValue);
	
	            $returnArr[$strKey] = $strValue;
	        }
	    }
	    return $returnArr;
	} //end of getConfigDetail
	function getDatabaseConnection()
	{
		 $usrnm = ""; // RETRIEVES THE USER NAME
		 $pwd = "";   // PASSWORD
		 $db = "cvt"; //DATABASE 
		 $databaseInfoArr = $this->getDatabaseDetails($db);
		 $strServer = $databaseInfoArr['strServer'];
		 $strTempUsr = $databaseInfoArr['strUserName'];
		 $strTempPwd = $databaseInfoArr['strPassword'];
		 $strTempPort = $databaseInfoArr['strPort']; //Task#8575
                  $this->logMessage(":980:0.0.0:Trying to connect mysql using ".$strServer.",".$strTempUsr.",".$strTempPwd.",".$strTempPort."." ,0); //Task#8575
		 $cvtconnection = @((($GLOBALS["___mysqli_ston"] = mysqli_init()) && (mysqli_real_connect($GLOBALS["___mysqli_ston"], $strServer,  $strTempUsr,  $strTempPwd, NULL, $strTempPort, NULL,  128))) ? $GLOBALS["___mysqli_ston"] : FALSE); //Task#8575
		 if ( $cvtconnection )
		 {
		 	 mysqli_select_db( $cvtconnection, $db);
		 }
	   return $cvtconnection;
	} //end of getDatabaseConnection
	function getDeviceIdentification($cvtconnection,$devicenbr, $uid , $type)
	{
	 	 $qryGet="SELECT /*CP19*/ recid, uid FROM device WHERE devicenbr='".$devicenbr."' AND status = 'A' AND (endeffdt IS NULL || endeffdt = '0000-00-00' || endeffdt > NOW())"; //Task#8889
	 	 $this->logMessage(":155:".$devicenbr.":".$uid.":".$incoming_ip.":getDeviceIdentification() Called For " . $devicenbr. "," . $uid . "," . $type   ,0);

		 $rsltGet=mysqli_query( $cvtconnection, $qryGet) ;
	 	 if(!$rsltGet) 
		 { 
	 	    $this->logMessage(":021:".$devicenbr.":".$uid.":".$incoming_ip.":getDeviceIdentification() Called For Type " . $type . " Return with 296 - " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
	      return "FAILED";
		 }
	   if ($rowGet = mysqli_fetch_assoc($rsltGet))
	 	 {
	 	  	if(!$rowGet) 
				{ 
	   	  	$this->logMessage(":022:".$devicenbr.":".$uid.":".$incoming_ip.":getDeviceIdentification() Called For Type " . $type . " Return with 295 - " . mysqli_error($GLOBALS["___mysqli_ston"]) , 1);
	        return "FAILED" ;				
				}
	 	  	$sysdeviceid=$rowGet['recid'];
	 	  	$sysuid=$rowGet['uid'];
			
			
			//Task#8928 Start
				$chr_STMCC = "N";
				$query = "SELECT /*cp19*/  ls.charvar chr_STMCC, d.recid deviceid
						 FROM   devicelocation dl,device d , locationsystem ls
						 WHERE  d.devicenbr='$devicenbr'
						 AND d.recid=dl.deviceid
						 AND ls.locationid = dl.locationid
						 AND ls.recid = 'STMCC'
						 AND (dl.endeffdt = '0000-00-00' OR dl.endeffdt IS NULL OR dl.endeffdt > NOW())"; //Task#8935

			   $this->logMessage(":300:".$devicenbr.":".$uid.":".$route.":".$incoming_ip.":getLocationId() Called For " . $devicenbr  ,0);
			   $rsltGet=mysqli_query( $cvtconnection, $query) ;
			   if(!$rsltGet) 
			   { 
				 $this->logMessage(":305:".$deviceid.":".$uid.":".$route.":".$incoming_ip.":getLocationId() Called Return with 296 - " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
				 
			   }
			   if ($rowGet = mysqli_fetch_assoc($rsltGet))
			   {
				  $chr_STMCC = $rowGet['chr_STMCC'];
				  
				  
				  
			   }
			   $deviceid =  $sysdeviceid;//Task#9006
			    $this->logMessage(":300:".$devicenbr.":".$uid.":".$chr_STMCC.":$sysuid != $uid:getLocationId() Called For " . $devicenbr  ,0);
			//Task#8928 End
	 	  	//device uid self registration logic start
	 	  	if ( (($sysuid === null or trim($sysuid)==='') or (($chr_STMCC == 'I' || $chr_STMCC == 'G') && $sysuid != $uid)) && $uid != '' ) //Task#8945
	 	  	{
				$qryUpd="UPDATE /*CP19*/ device SET uid = '" . $uid . "' WHERE recid='".$sysdeviceid."' "; //Task#8928
			   	$this->logMessage(":025:".$devicenbr.":".$uid.":".$incoming_ip.":getDeviceIdentification() Called Query : " . $qryUpd  ,0);
			   	
			   	mysqli_query( $cvtconnection, $qryUpd); 
			 //Task#8935 Start
			
				if ( mysqli_affected_rows($cvtconnection) >= 0 && ($chr_STMCC == 'I' || $chr_STMCC == 'G')) //Task#9006
				{				
					$this->logMessage(":026:".$devicenbr.":".$uid.":".$incoming_ip.":getDeviceIdentification() Called Passed." ,0);
					
	
					$qryUpd = "UPDATE /*CP19*/ rdsend SET datastatus  = \"Y\" WHERE deviceid='".$deviceid."' AND datastatus  = \"N\" AND type = \"C\" ";	
					mysqli_query( $cvtconnection, $qryUpd); 
					
					if ( mysqli_affected_rows($cvtconnection) >= 0 ) 
					 $this->logMessage(":026.1:".$devicenbr.":".$uid.":".$incoming_ip.":getDeviceIdentification Called datastatus   set Y." ,0);
					else
					{ 	
							if ( mysqli_errno($cvtconnection) )
							$this->logMessage(":026.1:".$devicenbr.":".$uid.":".$incoming_ip.":getDeviceIdentification Called Failed with " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
							else
							$this->logMessage(":026.1:".$devicenbr.":".$uid.":".$incoming_ip.":getDeviceIdentification Called Passed." ,0);
					}

					//Task#8973 Starts
					$qryCheck = "SELECT /*CP19*/ COUNT(1) as t_count FROM rdsend WHERE deviceid='".$deviceid."' AND datastatus  = 'Y' AND type = 'T'";
					$this->logMessage(":025:".$devicenbr.":".$uid.":".$incoming_ip.":getDeviceIdentification() Called Query : " . $qryCheck  ,0);
					$rsltCheck = mysqli_query( $cvtconnection, $qryCheck); 
					$rowCheck = mysqli_fetch_assoc($rsltCheck);
					if ($rowCheck['t_count'] == 0) {
                                            $runDate = date("Y-m-d");
                                            $qry1 = "SELECT /*CP19*/ companyid, locationid, personid FROM devicelocation WHERE deviceid = '" . $sysdeviceid . "'";
                                            $this->logMessage(":300:" . $devicenbr . ":" . $uid . ":" . $route . ":" . $incoming_ip . ":getLocationId() Called For " . $devicenbr, 0);
                                            $rslt1 = mysqli_query($cvtconnection, $qry1);
                                            if (!$rslt1) {
                                                $this->logMessage(":0111:" . $devicenbr . ":" . $uid . ":" . $incoming_ip . ":getDeviceIdentification Called For " . $qry1, 0);
                                            }
                                            if ($row1 = mysqli_fetch_assoc($rslt1)) {
                                                $clientId = $row1['companyid'];
                                                $clientLocId = $row1['locationid'];
                                                $personId = $row1['personid'];
                                            }

                                            $qry2 = "SELECT /*CP19*/ recid, type FROM route WHERE defaultdriverid = '$personId' AND type = 'SR' AND (endeffdt IS NULL OR endeffdt = '0000-00-00' OR endeffdt > NOW() )";
                                            $this->logMessage(":300:" . $devicenbr . ":" . $uid . ":" . $route . ":" . $incoming_ip . ":getLocationId() Called For " . $qry2, 0);
                                            $rslt2 = mysqli_query($cvtconnection, $qry2);
                                            if (!$rslt2) {
                                                $this->logMessage(":0111:" . $devicenbr . ":" . $uid . ":" . $incoming_ip . ":getDeviceIdentification Called For " . $qry2, 0);
                                            }
                                            if ($row2 = mysqli_fetch_assoc($rslt2)) {
                                                $routeId = $row2['recid'];
                                                $routeType = $row2['type'];
                                            }

                                            //Get dummyCustLocId
                                            $qry3 = "SELECT /*CP19*/ customerlocid FROM storeretrieve WHERE clientid = '$clientId' AND clientlocid = '$clientLocId' AND type = 'E' AND integer2 = '$routeId' AND strvar3 = 'TMC'";
                                            $rslt3 = mysqli_query($cvtconnection, $qry3);
                                            if (!$rslt3) {
                                                $this->logMessage(":0111:" . $devicenbr . ":" . $uid . ":" . $incoming_ip . ":getDeviceIdentification Called For " . $qry3, 0);
                                            }
                                            if ($row3 = mysqli_fetch_assoc($rslt3)) {
                                                $dummyCustLocId = $row3['customerlocid'];
                                            }

                                            //Get INDEF
                                            $qryGet = "SELECT /*CP19*/ DATE_FORMAT(datevar, '%Y-%m-%d') datevar FROM system WHERE recid= 'INDEF'";
                                            $this->logMessage(":0111:" . $devicenbr . ":" . $uid . ":" . $incoming_ip . ":getDeviceIdentification Called For " . $qryGet, 0);
                                            $rsltGet = mysqli_query($cvtconnection, $qryGet);
                                            if ($rowGet = mysqli_fetch_assoc($rsltGet)) {
                                                $val_INDEF = $rowGet['datevar'];
                                            }

                                            //INSERT A RECORD IN SPECIFICROUTES
                                            $split0 = $this->getSplit($cvtconnection, $clientLocId, $devicenbr, $uid, 0);
                                            $qryIns = "INSERT /*CP19*/ INTO specificroutes" . $split0 . "(dispatchlocid, routeId, datesked, timesked, endtimesked, sdesc, status, driverid, vehicleid, deviceid, sentflag, message)
                                                VALUES
                                                ('$clientLocId', '$routeId', '$runDate', CURTIME(), '00:00:00', 
                                                '', 'A', '$personId', '0', '$sysdeviceid', 'N', '')";
                                            mysqli_query($cvtconnection, $qryIns);
                                            if (mysqli_affected_rows($cvtconnection) >= 0) {
                                                $specificRouteId = mysqli_insert_id($cvtconnection);
                                                if (!is_numeric($specificRouteId))
                                                    $specificRouteId = 0;
                                                $this->logMessage(":0111:" . $devicenbr . ":" . $uid . ":" . $incoming_ip . ":getDeviceIdentification Called For " . $qryIns, 0);
                                            }

                                            //INSERT A RECORD IN specificrouteloc
                                            $qryIns = "INSERT /*CP19*/ INTO specificrouteloc" . $split0 . " (specificrouteid, locationid, subrouteid,  relativetime, comment, sentflag, clientlocid) 
                                                VALUES
                                                ('$specificRouteId', '$dummyCustLocId', '$routeId',  '', '',  'N', '$clientLocId')";
                                            mysqli_query($cvtconnection, $qryIns);
                                            if (mysqli_affected_rows($cvtconnection) >= 0) {
                                                $this->logMessage(":0111:" . $devicenbr . ":" . $uid . ":" . $incoming_ip . ":getDeviceIdentification Called For " . $qryIns, 0);
                                            }

                                            //Find specificproduct
                                            $qryGetSpInfo = "SELECT /*CP19*/ sp.recid spId FROM specificproduct sp, clientsystem cs WHERE sp.productid = cs.intvar AND cs.recid = 'CMNPR' AND cs.clientid = '$clientId' AND sp.datex = '$runDate' AND (sp.endeffdt IS NULL OR sp.endeffdt = '0000-00-00' OR sp.endeffdt > '$runDate' )";
                                            $this->logMessage(":0111:" . $devicenbr . ":" . $uid . ":" . $incoming_ip . ":getDeviceIdentification Called For " . $qryGetSpInfo, 0);
                                            $rsltGetSpInfo = mysqli_query($cvtconnection, $qryGetSpInfo);
                                            if ($rowGetSpInfo = mysqli_fetch_assoc($rsltGetSpInfo)) {
                                                $spId = $rowGetSpInfo['spId'];
                                                if (!is_numeric($spId))
                                                    $spId = 0;
                                            }

                                            //INSERT INTO TRANSACTIVITY
                                            $qryIns = "INSERT /*CP19*/ INTO transactivity" . $split0 . "(locationid, type, customerlocid, specificrouteid, personid, specificproductid, actquantity, datet, closeddatecust, closeddatevend, closeddatevendinv, closeddatecustpay)
                                                VALUES ('$clientLocId', 'SD', '$dummyCustLocId', '$specificRouteId', '$personId',
                                                '$spId', 1, '$runDate', '$val_INDEF', '$val_INDEF', '$val_INDEF', '$val_INDEF')";
                                            mysqli_query($cvtconnection, $qryIns);
                                            if (mysqli_affected_rows($cvtconnection) >= 0) {
                                                $this->logMessage(":0111:" . $devicenbr . ":" . $uid . ":" . $incoming_ip . ":getDeviceIdentification Called For " . $qryIns, 0);
                                            }

                                            //Create RDSEND
                                            //NOW CHECK FOR RDSEND RECORD AND IF NOT EXIST INSERT ONE AND IF EXIST THEN UPDATE ITS DEVICEID
                                            $qryChkRecs = "SELECT /*CP19*/ recid FROM rdsend
                                                                        WHERE devicestatus = 'N'
                                                                        AND type = 'T'
                                                                        AND specificroutesid = '$specificRouteId'
                                                                        AND deviceid = '$sysdeviceid'";
											$this->logMessage(":0111:" . $devicenbr . ":" . $uid . ":" . $incoming_ip . ":getDeviceIdentification Called For " . $qryChkRecs, 0);
                                            $rsltChkRecs = mysqli_query($cvtconnection, $qryChkRecs);
                                            if (!$rsltChkRecs) {
                                                $this->logMessage(":0111:" . $devicenbr . ":" . $uid . ":" . $incoming_ip . ":getDeviceIdentification Called For " . $qryChkRecs, 0);
                                            }
                                            if ($rowChkRecs = mysqli_fetch_assoc($rsltChkRecs)) {
                                                $rdSendId = $row3['recid'];
                                                if (!is_numeric($rdSendId))
                                                    $rdSendId = 0;
                                            } else {
                                                $rdSendId = 0;
                                            }

                                            $this->logMessage(":0111:" . $devicenbr . ":" . $uid . ":" . $incoming_ip . ":rdSendId = " . $rdSendId, 0);

                                            if ($rdSendId == 0) {
                                                $qryIns = "INSERT /*CP19*/ INTO rdsend(devicestatus, datastatus, type, specificroutesid, deviceid, dpversion)
                                                                                                VALUES('N', 'Y', 'T', '$specificRouteId', '$sysdeviceid', 'DP0014')";
                                                mysqli_query($cvtconnection, $qryIns);
                                                if (mysqli_affected_rows($cvtconnection) >= 0) {
                                                    $this->logMessage(":0111:" . $devicenbr . ":" . $uid . ":" . $incoming_ip . ":getDeviceIdentification Called For " . $qryIns, 0);
                                                }
                                            } else {
                                                // UPDATE THE DEVICEID
                                                $qryUp = "UPDATE /*CP19*/ rdsend
                                                                    SET deviceid = '$sysdeviceid',
                                                                    dpversion = '$dpVersion',
                                                                    datastatus = 'Y'
                                                                    WHERE recid = '$rdSendId'";
                                                mysqli_query($cvtconnection, $qryUp);
                                                if (mysqli_affected_rows($cvtconnection) >= 0) {
                                                    $this->logMessage(":0111:" . $devicenbr . ":" . $uid . ":" . $incoming_ip . ":getDeviceIdentification Called For " . $qryUp, 0);
                                                }
                                            }
                                            unset($rdSendId);
                                        }//END if($rowCheck['t_count'] == 0)
                                        //Task#8973 Ends
                                    } 
				//Task#8935 End
			   	else
			   	{ 	
						if ( mysqli_errno($cvtconnection) ) //Task#8935
						{
							$this->logMessage(":027:".$devicenbr.":".$uid.":".$incoming_ip.":getDeviceIdentification() Called Failed with Return with 297 - " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
							return "FAILED" ;	
						}	
						else
						{
						 $sysuid = $uid;	
			       $this->logMessage(":028:".$devicenbr.":".$uid.":".$incoming_ip.":getDeviceIdentification() Called Successfully Device UID Self Registered." ,0);
			      } 
			    }		 	 	  		
	 	  	}
	 	  	else if ( $sysuid == $uid ) 
	 	  	{
	 	  		$this->logMessage(":029:".$devicenbr.":".$uid.":".$incoming_ip.":getDeviceIdentification() Called Successfully Device UID Matches." ,0);
				
	 	  	}
	 	  	else
	 	  	{
				//Task#8928 Start
				
				if(($chr_STMCC == 'I' || $chr_STMCC == 'G') && $uid != '') //Task#8945
				{
					$this->logMessage(":029.1:".$devicenbr.":".$uid.":".$incoming_ip.":getDeviceIdentification() , Skip Device UID Matches process ,STMCC.charvar = '$chr_STMCC'." ,0);	
				}else{
					$this->logMessage(":030:".$devicenbr.":".$uid.":".$incoming_ip.":getDeviceIdentification() Failed to Matche UID Code." ,1);
					return "FAILED" ;	
				}
				//Task#8928 End
	 	  	}
	 	  	//device uid self registration logic end
	 	  	if ( $type == "I" ) 
	 	  	$identification = "[device]".$devicenbr;
	 	  	else
	 	  	$identification = "[device]".$sysdeviceid;
	 	  	
	 	  	return $identification;
	 	 }
	 	 else
	 	 {
	 	  	$this->logMessage(":012:".$devicenbr.":".$uid.":".$incoming_ip.":getDeviceIdentification() Called For Type " . $type . " Return with 997",1);
	      return "FAILED" ;
	 	 }	 
	}	//end of getDeviceIdentification

	function getDeviceId($cvtconnection,$devicenbr, $uid)
	{
	 	 $qryGet="select recid from device where devicenbr='".$devicenbr."' And uid = '".$uid."'";
	 	 $this->logMessage(":1400:".$devicenbr.":".$uid.":".$incoming_ip.":getDeviceId() Called For " . $devicenbr. "," . $uid  ,0);

		 $rsltGet=mysqli_query( $cvtconnection, $qryGet) ;
	 	 if(!$rsltGet) 
		 { 
	 	    $this->logMessage(":1405:".$devicenbr.":".$uid.":".$incoming_ip.":getDeviceId() Called Return with 296 - " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
	      return "FAILED";
		 }
	   if ($rowGet = mysqli_fetch_assoc($rsltGet))
	 	 {
	 	  	if(!$rowGet) 
				{ 
	   	  	$this->logMessage(":1410:".$devicenbr.":".$uid.":".$incoming_ip.":getDeviceId() Called Return with 295 - " . mysqli_error($GLOBALS["___mysqli_ston"]) , 1);
	        return "FAILED" ;				
				}
	 	  	$sysdeviceid=$rowGet['recid'];
	 	  	return $sysdeviceid;
	 	 }
	 	 else
	 	 {
	 	  	$this->logMessage(":1412:".$devicenbr.":".$uid.":".$incoming_ip.":getDeviceId() Called Return with 997",1);
	      return "FAILED" ;
	 	 }	 
	}	//end of getDeviceId
	function getDeviceNbr($cvtconnection,$deviceid, $uid)
	{
	 	 $qryGet="select devicenbr from device where recid='".$deviceid."' And uid = '".$uid."'";
	 	 $this->logMessage(":1500:".$deviceid.":".$uid.":".$incoming_ip.":getDeviceNbr() Called For " . $deviceid. "," . $uid ,0);

		 $rsltGet=mysqli_query( $cvtconnection, $qryGet) ;
	 	 if(!$rsltGet) 
		 { 
	 	    $this->logMessage(":1505:".$deviceid.":".$uid.":".$incoming_ip.":getDeviceNbr() Called Return with 296 - " . mysqli_error($GLOBALS["___mysqli_ston"]) ,1);
	      return "FAILED";
		 }
	   if ($rowGet = mysqli_fetch_assoc($rsltGet))
	 	 {
	 	  	if(!$rowGet) 
				{ 
	   	  	$this->logMessage(":1510:".$deviceid.":".$uid.":".$incoming_ip.":getDeviceNbr() Called Return with 295 - " . mysqli_error($GLOBALS["___mysqli_ston"]) , 1);
	        return "FAILED" ;				
				}
	 	  	$sysdeviceid=$rowGet['devicenbr'];
	 	  	return $sysdeviceid;
	 	 }
	 	 else
	 	 {
	 	  	$this->logMessage(":1520:".$deviceid.":".$uid.":".$incoming_ip.":getDeviceNbr() Called Return with 997",1);
	      return "FAILED" ;
	 	 }	 
	}	//end of getDeviceNbr
	function getClientIP() 
	{
	    $ipaddress = '';
	    if ($_SERVER['HTTP_CLIENT_IP'])
	        $ipaddress = $_SERVER['HTTP_CLIENT_IP'];
	    else if($_SERVER['HTTP_X_FORWARDED_FOR'])
	        $ipaddress = $_SERVER['HTTP_X_FORWARDED_FOR'];
	    else if($_SERVER['HTTP_X_FORWARDED'])
	        $ipaddress = $_SERVER['HTTP_X_FORWARDED'];
	    else if($_SERVER['HTTP_FORWARDED_FOR'])
	        $ipaddress = $_SERVER['HTTP_FORWARDED_FOR'];
	    else if($_SERVER['HTTP_FORWARDED'])
	        $ipaddress = $_SERVER['HTTP_FORWARDED'];
	    else if($_SERVER['REMOTE_ADDR'])
	        $ipaddress = $_SERVER['REMOTE_ADDR'];
	    else
	        $ipaddress = 'UNKNOWN';
	 
	    return $ipaddress;
	} //end of getClientIP
	function isEmpty($input) 
	{
	    $strTemp = $input;
	    $strTemp = trim($strTemp);
	    if ( $strTemp == '') 
	    {
	       return true;
	    }
	    if( strlen($strTemp) == 0)
	    {
	    	return true;
	    }
	    return false;
	} //end of isEmpty($input) 
	function endswith($string, $test) 
	{
    return true;
    $strlen = strlen($string);
    $testlen = strlen($test);
    if ($testlen > $strlen) return false;
    /*
    return substr_compare($string, $test, -1 * ($testlen) ) ;
    */
    
		$length = strlen($test);
    if ($length == 0) { return true; }
    return (substr($string, -$length) === $test);    
    
	} //end of endsWith($haystack, $needle)
	
} //end of class cp19

ini_set("soap.wsdl_cache_enabled", "0");
$server = new SoapServer("cp19.wsdl");
$server->setClass("Cp19");
$server->handle();

?>
