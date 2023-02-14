/*
Version History
====================================
Version.    Modi.Date       Modi.By         Description
1.2			2020-08-04		Devarshi		#8786 Modify this service to keep track of Gpslocqueue records being processed for each client location so that we can bill the client using the activity table data for each month.
1.1         2020-03-17      Devarshi        #8541 change in service to support TMC mode
0.0         2019-09-27      Devarshi        #8269 get latlong and address through smartyStreet API
====================================
 fs_copyrights : Teak System Incorporated
 */

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.Calendar;
import java.util.HashMap;
import java.util.Map;
import java.util.TimeZone;
import java.util.Vector;
import java.util.logging.Level;
import java.util.logging.Logger;

/*
PROGRAM IDENTIFICATION
------------------------
PROGRAM FILE NAME   :  SE065.java

CREATOR NAME        :   DEV

DATE OF CREATION    :   27-09-2019

CREATED FOR         :   Teak Systems Incorporated

DESCRIPTION         :   get latlong and full address from SamrtyStreet API and update it in Address table

(c) COPYRIGHT Teak Systems Incorporated
=================================================================

 */
public class SE065 {

    static Connection con = null;
    String error = "";
    String groupCode = "s65";
    String subject = "Error in SE065 service";
    static String connStr = null;

    public void createConnection() {
        FileReader fr;
        BufferedReader br;
        String s = "", conString = "";
        try {
            fr = new FileReader("//usr//local//twce//se//zz//system_vari.txt");
            br = new BufferedReader(fr);
            while ((s = br.readLine()) != null) {
                if (s.startsWith("driver:=")) {
                    conString = s.substring(8);
                    break;
                }
            }
            br.close();
            fr.close();
        } catch (Exception e) {
            error = getDateTime() + ": SE065 : createConnection : Error occured during connection file read : " + e;
            notifyEmail(error);
            System.err.println(error);
            conString = null;
        }
        connStr = conString;

        try {
            Class.forName("com.mysql.jdbc.Driver").newInstance();
            con = DriverManager.getConnection(connStr);
        } catch (Exception e) {
            error = getDateTime() + ": SE065 : createConnection : Error occured during loading driver : " + e;
            notifyEmail(error);
            System.err.println(error);
        }
    }

    private void startProcess(String authId, String authToken) {
        String query = "";
        try {
            Statement stmt = con.createStatement();
            Statement stmt1 = con.createStatement();//Task#8541
            ResultSet rs = null, rs1 = null;
            long recId = 0;

            ArrayList<Lookup> lookup = new ArrayList<>();
            PreparedStatement addressQry = null;
            PreparedStatement statusUpdateQry = null;
            PreparedStatement updateOutgoingAddress = null;

            String addressQry1 = "SELECT /*SE065*/ address1,address2,\n"
                    + "    address3,address4,\n"
                    + "    city, state,\n"
                    + "    postalcode\n"
                    + "    FROM  `address`\n"
                    + "    WHERE `recid` = ?";
            addressQry = con.prepareStatement(addressQry1);

            String statusUpdateQry1 = "UPDATE /*SE065*/ gpslocqueue set status=?  where recid= ?";
            statusUpdateQry = con.prepareStatement(statusUpdateQry1);

            String updateOutgoingAddress1 = "update /*SE065*/ gpslocqueue set outgoingaddress=? WHERE recid=?";
            updateOutgoingAddress = con.prepareStatement(updateOutgoingAddress1);

            query = "update /*SE065*/ gpslocqueue set status='N'  WHERE status='P'";//set 'N' for unprocessed address
            System.out.println(getDateTime() + ":main: query 0 :" + query);
            stmt.executeUpdate(query);

            //Commnted#8541 start
            //query = "SELECT /*SE065*/ recid,custaddressId from gpslocqueue WHERE status ='N' Limit 99";//max limit in one batch is 100 addresses
            //Commnted#8541 End
            //Task#8541 start
            query = "SELECT /*SE065*/ customerlocid,recid,custaddressId from gpslocqueue WHERE status ='N' Limit 99";//max limit in one batch is 100 addresses
            //Task#8541 End
            System.out.println(getDateTime() + ":main: query 3 :" + query);
            rs = stmt.executeQuery(query);
            while (rs.next()) {
                long custAddressId = 0;
                recId = rs.getLong("recid");
                custAddressId = rs.getLong("custaddressId");
                String customerLocId = rs.getString("customerlocid");//Task#8541 

                //set status to 'P' as record is in process
                System.out.println(getDateTime() + " :startProcess update flag p query 2:" + statusUpdateQry1 + " with addressid:" + custAddressId);
                statusUpdateQry.setString(1, "P");
                statusUpdateQry.setLong(2, recId);
                statusUpdateQry.executeUpdate();

                if (customerLocId != null && !customerLocId.equalsIgnoreCase("") && !customerLocId.equalsIgnoreCase("0")) {//Task#8541 
                    addressQry.setLong(1, custAddressId);
                    System.out.println(getDateTime() + " :startProcess get address query 3:" + addressQry1 + " with addressid:" + custAddressId);
                    rs1 = addressQry.executeQuery();

                    if (rs1.next()) {
                        String address1 = "", address2 = "", address3 = "", address4 = "", city = "", state = "", postalCode = "";
                        address1 = rs1.getString("address1");
                        address2 = rs1.getString("address2");
                        address3 = rs1.getString("address3");
                        address4 = rs1.getString("address4");
                        city = rs1.getString("city");
                        state = rs1.getString("state");
                        postalCode = rs1.getString("postalcode");

                        if ((address1 == null || address1.isEmpty()) && (address2 == null || address2.isEmpty()) && (address3 == null || address3.isEmpty()) && (address4 == null || address4.isEmpty())) {
                            //error code
                            setErrorStatus("" + recId);
                        } else {
                            String address = "", outgoingAddress;
                            //make lookup for addresses
                            Lookup address0 = new Lookup();
                            if (address1 != null) {
                                address = address1;
                            }
                            if (address2 != null) {
                                address = address + " " + address2;
                            }
                            if (address3 != null) {
                                address = address + " " + address3;
                            }
                            if (address4 != null) {
                                address = address + " " + address4;
                            }
                            address = address.trim();
                            System.out.println("address:" + address);
                            System.out.println("city:" + city);
                            System.out.println("state:" + state);
                            System.out.println("postalCode:" + postalCode);
                            outgoingAddress = address + " " + city + " " + state + " " + postalCode;
                            //set outgoing addresss in gpslocqueue
                            System.out.println(getDateTime() + " :startProcess update outgoing address query 3:" + updateOutgoingAddress1 + " with recid:" + custAddressId);
                            updateOutgoingAddress.setString(1, outgoingAddress);
                            updateOutgoingAddress.setLong(2, recId);
                            updateOutgoingAddress.executeUpdate();

                            address0.setInputId("" + recId);
                            address0.setStreet(address);
                            if (!city.isEmpty()) {
                                address0.setCity(city);
                            }
                            if (!state.isEmpty()) {
                                address0.setState(state);
                            }
                            if (!postalCode.isEmpty()) {
                                address0.setZipCode(postalCode);
                            }
                            address0.setMatch(MatchType.INVALID);
                            address0.setMaxCandidates(1);
                            lookup.add(address0);
                        }
                    } else {
                        //error code
                        setErrorStatus("" + recId);//set error code if address is empty
                    }
                    //Task#8541 start
                } else {
                    Lookup address0 = new Lookup();
                    query = "SELECT /*SE065*/\n"
                            + "    sr.strvar2\n"
                            + "FROM\n"
                            + "    gpslocqueue glq,\n"
                            + "    storeretrieve sr\n"
                            + "WHERE\n"
                            + "    glq.custaddressid=sr.recid and glq.recid=" + recId + "";
                    System.out.println(getDateTime() + ":main: query 4 :" + query);
                    rs1 = stmt1.executeQuery(query);

                    String strvar = "", address = "", city = "", state = "", postalCode = "";
                    if (rs1.next()) {
                        strvar = rs1.getString("strvar2");
                    }
                    if (!strvar.isEmpty()) {
                        String splits[] = strvar.split("~");
                        address = splits[0].trim();
                        city = splits[1].trim();
                        state = splits[2].trim();
                        postalCode = splits[3].trim();

                        System.out.println("address=" + address);
                        System.out.println("city=" + city);
                        System.out.println("state=" + state);
                        System.out.println("postalCode=" + postalCode);

                        String outgoingAddress=address+" "+city+" "+state+" "+postalCode;
                        updateOutgoingAddress.setString(1, outgoingAddress);
                        updateOutgoingAddress.setLong(2, recId);
                        updateOutgoingAddress.executeUpdate();

                        address0.setInputId("" + recId);
                        address0.setStreet(address);
                        address0.setCity(city);
                        address0.setState(state);
                        address0.setZipCode(postalCode);

                        address0.setMatch(MatchType.INVALID);
                        address0.setMaxCandidates(1);
                        lookup.add(address0);
                    } else {
                        setErrorStatus("" + recId);
                    }
                }
                //Task#8541 End
            }
            System.out.println("tete teet");
            if (!lookup.isEmpty()) {
                StaticCredentials credentials = new StaticCredentials(authId, authToken);
                Client client = new ClientBuilder(credentials).buildUsStreetApiClient();
                Batch batch = new Batch();
                int responceCode = 0;
                try {
                    for (Lookup l : lookup) {
                        batch.add(l);
                    }
                    responceCode = client.send(batch);
                    //as we got result set flag=Y
                    setBunchStatus("P", "Y");

                } catch (BatchFullException ex) {
                    System.out.println("Oops! Batch was already full. error" + ex);
                } catch (SmartyException ex) {
                    System.out.println(ex.getMessage());
                    setResponceCode("" + ex);
                    //set responce code
                } catch (IOException ex) {
                    System.out.println(ex.getMessage());
                    setResponceCode("" + ex);
                }
                if (responceCode == 200) {
                    setResponceCode("" + responceCode + ": OK");
                    Vector<Lookup> lookups = batch.getAllLookups();

                    for (int i = 0; i < batch.size(); i++) {
                        ArrayList<Candidate> candidates = lookups.get(i).getResult();

                        if (candidates.isEmpty()) {
                            System.out.println(getDateTime() + ": rec id" + batch.get(i).getInputId() + " is invalid.\n");
                            String recId1 = batch.get(i).getInputId();
                            setErrorStatus(recId1);
                            continue;
                        }

                        System.out.println(getDateTime() + ": rec id" + batch.get(i).getInputId() + " is valid. ");

                        candidates.forEach((candidate) -> {
                            //we set candidate=1
                            String recId1 = lookup.get(candidate.getInputIndex()).getInputId();
                            processResponce(candidate, recId1);
                        });
                    }
                    sendBadAddressMail();
                } else {
                    error = getDateTime() + ":  : startProcess : Error while getttng data : last Query:" + query + " with : ";
                    notifyEmail(error);
                    System.err.println(error);
                    setBunchStatus("P", "C");
                }
            }
        } catch (Exception ex) {
            error = getDateTime() + ":  : startProcess : Error occured : last Query:" + query + " with : " + ex;
            notifyEmail(error);
            System.err.println(error);
            Logger.getLogger(SE065.class.getName()).log(Level.SEVERE, null, ex);
        } finally {
            query = null;
        }
    }

    public void setBunchStatus(String fromStatus, String toStatus) throws SQLException {
        Statement stUpdate = con.createStatement();
        String query = "UPDATE /*SE065*/ gpslocqueue set status='" + toStatus + "'  where status='" + fromStatus + "' ";
        stUpdate.executeUpdate(query);
    }

    public void setErrorStatus(String recId) throws SQLException {
        Statement stUpdate = con.createStatement();
        String query = "UPDATE /*SE065*/ gpslocqueue set status='C'  where recid='" + recId + "' ";
        stUpdate.executeUpdate(query);
    }

    public void setResponceCode(String code) throws SQLException {
        Statement stUpdate = con.createStatement();
        String query = "UPDATE /*SE065*/ gpslocqueue set responsecode='" + code + "'  where status='P' OR status='Y'";
        stUpdate.executeUpdate(query);
    }

    public void processResponce(Candidate candidate, String recId1) {
        String query = "";
        try {
            String statusUpdateQry1 = "UPDATE /*SE065*/ gpslocqueue set status=?  where recid= ? AND status= ?";
            PreparedStatement statusUpdateQry = con.prepareStatement(statusUpdateQry1);

            Statement stmt = con.createStatement();
            Statement stmt3 = con.createStatement();
            Statement stUpdate = con.createStatement();
            ResultSet rs = null, rs3 = null;

            Components components = candidate.getComponents();
            Metadata metadata = candidate.getMetadata();
            Analysis analysis = candidate.getAnalysis();
            System.out.println("\nCandidate " + candidate.getCandidateIndex() + ":");
            System.out.println("Delivery line 1: " + candidate.getDeliveryLine1());
            System.out.println("Last line:       " + candidate.getLastLine());
            System.out.println("city             " + components.getCityName());
            System.out.println("state             " + components.getState());
            System.out.println("ZIP Code:        " + components.getZipCode() + "-" + components.getPlus4Code());
            System.out.println("County:          " + metadata.getCountyName());
            System.out.println("Latitude:        " + metadata.getLatitude());
            System.out.println("Longitude:       " + metadata.getLongitude());
            System.out.println("recordType:       " + metadata.getRecordType());
            System.out.println("dpv_match_code:  " + analysis.getDpvMatchCode());
            System.out.println("dpv_footnotes:   " + analysis.getDpvFootnotes());
            String deliveryLine1 = "", lastLine = "", city = "", state = "", baseZipCode = "", primaryNo = "", zipCodePlus4 = "", zipCode = "", county = "";
            String dpvMatchCode = "", dpvFootnotes = "", footnotes = "", recordType = "";
            double lat = 0, lng = 0;

            deliveryLine1 = candidate.getDeliveryLine1();
            lastLine = candidate.getLastLine();
            city = components.getCityName();
            state = components.getState();
            baseZipCode = components.getZipCode();
            zipCodePlus4 = components.getPlus4Code();
            lat = metadata.getLatitude();
            lng = metadata.getLongitude();
            county = metadata.getCountyName();
            primaryNo = components.getPrimaryNumber();
            dpvMatchCode = analysis.getDpvMatchCode();
            dpvFootnotes = analysis.getDpvFootnotes();
            footnotes = analysis.getFootnotes();
            recordType = metadata.getRecordType();
            zipCode = baseZipCode;

            long customerLocId = 0;
            long custAddressId = 0;
            long clientLocId = 0, clientId = 0, specificRouteId = 0;
            String stdad = "N", homerCharVar = "", split = "";

            System.out.println(getDateTime() + " :startProcess update flag Q query 1:" + statusUpdateQry1 + " with recId1:" + recId1);
            statusUpdateQry.setString(1, "Q");
            statusUpdateQry.setString(2, recId1);
            statusUpdateQry.setString(3, "Y");
            statusUpdateQry.executeUpdate();

            //set latlong in gpslocqueue
            if (dpvMatchCode == null) {
                dpvMatchCode = "";
            }
            if (dpvMatchCode.equals("null")) {
                dpvMatchCode = "";
            }
            //Commented#8541 start
            //String structuredAddress = deliveryLine1 + " " + lastLine + " " + city + " " + state + " " + zipCode + " " + county + " ";
            //Commented#8541 end
            //Task#8541 start
            String structuredAddress = deliveryLine1 + " " + city + " " + state + " " + zipCode + " " + county + " ";
            //Task#8541 end
            query = "UPDATE /*SE065*/ gpslocqueue set structuredaddress=\"" + structuredAddress + "\", latlong=\"" + lat + "|" + lng + "\",dpvmatchcode='" + dpvMatchCode + "',  \n"
                    + "dpvfootnotes='" + dpvFootnotes + "',recordtype='" + recordType + "', footnotes='" + footnotes + "' where recid=" + recId1 + "  ";
            System.out.println(getDateTime() + " :processResponce: query 2:" + query);
            stUpdate.executeUpdate(query);

            query = "SELECT /*SE065*/ clientlocid,`customerlocid`,`custaddressid` from gpslocqueue WHERE recid=" + recId1 + " and `status`='Q'";
            System.out.println(getDateTime() + " :processResponce: query :" + query);
            rs = stmt.executeQuery(query);
            if (rs.next()) {
                clientLocId = rs.getLong("clientlocid");
                customerLocId = rs.getLong("customerlocid");
                custAddressId = rs.getLong("custaddressId");

                //Task#8541 start 
                if (customerLocId != 0) {//if Processs is not for TMC locations 
                    //Task#8541 end
                    //find if address reqire to be updated or not 
                    query = "SELECT /*SE065*/ charvar FROM locationsystem where recid = \"STDAD\" AND locationid = " + clientLocId + " ";
                    System.out.println(getDateTime() + " :processResponce: query 3:" + query);
                    rs3 = stmt3.executeQuery(query);
                    if (rs3.next()) {
                        stdad = rs3.getString("charvar");
                    }

                    //find address is homer or not
                    query = "SELECT /*SE065*/ charvar FROM locationsystem where recid = \"HOMER\" AND locationid = " + clientLocId + " ";
                    System.out.println(getDateTime() + " :processResponce: query 4:" + query);
                    rs3 = stmt3.executeQuery(query);
                    if (rs3.next()) {
                        homerCharVar = rs3.getString("charvar");
                    } else {
                        homerCharVar = "null";
                    }

                    query = "SELECT /*SE065*/ companyid FROM locationlink WHERE locationid=" + clientLocId + "";
                    System.out.println(getDateTime() + " :processResponce: query 5:" + query);
                    rs3 = stmt3.executeQuery(query);
                    if (rs3.next()) {
                        clientId = rs3.getInt("companyid");
                    }

                    query = "SELECT /*SE065*/ strvar from clientsystem WHERE recid=\"SPLIT\" AND clientid=" + clientId + "";
                    System.out.println(getDateTime() + " :processResponce: query 6:" + query);
                    rs3 = stmt3.executeQuery(query);
                    if (rs3.next()) {
                        split = rs3.getString("strvar");
                    }

                    query = "SELECT /*SE065*/ spr.recid from specificroutes" + split + " spr,standardroutes sr WHERE spr.dispatchlocid=" + clientLocId + "  AND spr.routeid = sr.routeid AND spr.datesked =CURDATE()  AND sr.locationid = " + customerLocId + " ";
                    System.out.println(getDateTime() + " :processResponce: query 7:" + query);
                    rs3 = stmt3.executeQuery(query);
                    if (rs3.next()) {
                        specificRouteId = rs3.getLong("recid");
                    }

                    //compare mactch code and footnotes to find qulity of address and latlong
                    if (dpvMatchCode != null && !dpvMatchCode.equals("null") && !dpvMatchCode.isEmpty() && !recordType.isEmpty() && !recordType.equals("G") && !recordType.equals("P") && !recordType.equals("R")) {//address is valid                   
                        query = "UPDATE /*SE065*/ address set latlong=\"" + lat + "|" + lng + "\",latitude=" + lat + ",longitude=" + lng + " where  recid=" + custAddressId + " ";
                        System.out.println(getDateTime() + " :processResponce: query 8:" + query);
                        stUpdate.executeUpdate(query);

                        if (specificRouteId != 0) {
                            query = "UPDATE /*SE065*/ specificrouteloc" + split + " set latlongactual=\"" + lat + "|" + lng + "\",archupdt=\"U\" WHERE clientlocid = " + clientLocId + " AND locationid=" + customerLocId + "  AND specificrouteid=" + specificRouteId + "   ";
                            System.out.println(getDateTime() + " :processResponce: query 9:" + query);
                            stUpdate.executeUpdate(query);
                        }

                        if (!stdad.equals("N")) {
                            String address1 = deliveryLine1;
                            System.out.println("address1=" + address1);
                            if (stdad.equals("A") || stdad.equals("D") || stdad.equals("M") || stdad.equals("R")) {

                                //if not homer then don't split number part else put number part in address1
                                if ((homerCharVar.equals("null") || homerCharVar.equals("S"))) {
                                    address1 = address1.trim();
                                    query = "UPDATE /*SE065*/ address set address1=\"" + address1 + "\",address2='',address3='',address4='',city=\"" + city + "\",state=\"" + state + "\",postalcode=\"" + zipCode + "\",county='" + county + "'  WHERE recid=" + custAddressId + "";
                                    System.out.println(getDateTime() + " :processResponce: query 11:" + query);
                                    stUpdate.executeUpdate(query);
                                } else if (homerCharVar.trim().equals("3")) {
                                    address1 = address1.substring(address1.indexOf(" ")).trim();
                                    query = "UPDATE /*SE065*/ address set address1=\"" + primaryNo + "\",address2=\"" + address1 + "\",address3='',address4='',city=\"" + city + "\",state=\"" + state + "\",postalcode=\"" + zipCode + "\",county='" + county + "'  WHERE recid=" + custAddressId + "";
                                    System.out.println(getDateTime() + " :processResponce: query 11:" + query);
                                    stUpdate.executeUpdate(query);
                                }
                            }
                        }
                        System.out.println(getDateTime() + " :startProcess update flag F query :" + statusUpdateQry1 + " with recId1:" + recId1);
                        statusUpdateQry.setString(1, "F");
                        statusUpdateQry.setString(2, recId1);
                        statusUpdateQry.setString(3, "Q");
                        statusUpdateQry.executeUpdate();
                    } else { //address is not valid                   

                        System.out.println(getDateTime() + " :startProcess update flag C query :" + statusUpdateQry1 + " with recId1:" + recId1);
                        statusUpdateQry.setString(1, "C");
                        statusUpdateQry.setString(2, recId1);
                        statusUpdateQry.setString(3, "Q");
                        statusUpdateQry.executeUpdate();
                    }
                    //Task#8541 start
                } else {
                    if (dpvMatchCode != null && !dpvMatchCode.equals("null") && !dpvMatchCode.isEmpty() && !recordType.isEmpty() && !recordType.equals("G") && !recordType.equals("P") && !recordType.equals("R")) {//address is valid                   
                        query = "UPDATE /*SE065*/ storeretrieve set strvar1 =\"" + lat + "|" + lng + "\",float1 =" + lat + ",float2=" + lng + " where  recid=" + custAddressId + " ";
                        System.out.println(getDateTime() + " :processResponce: query 8:" + query);
                        stUpdate.executeUpdate(query);

                        System.out.println(getDateTime() + " :processResponce update flag F query :" + statusUpdateQry1 + " with recId1:" + recId1);
                        statusUpdateQry.setString(1, "F");
                        statusUpdateQry.setString(2, recId1);
                        statusUpdateQry.setString(3, "Q");
                        statusUpdateQry.executeUpdate();
                    } else { //address is not valid
                        System.out.println(getDateTime() + " :processResponce update flag C query :" + statusUpdateQry1 + " with recId1:" + recId1);
                        statusUpdateQry.setString(1, "C");
                        statusUpdateQry.setString(2, recId1);
                        statusUpdateQry.setString(3, "Q");
                        statusUpdateQry.executeUpdate();
                    }
                }
				setActivityData(""+clientLocId); //Task#8786
                //Task#8541 end
            }

        } catch (Exception ex) {
            error = getDateTime() + ":  : processResponce : Error occured : last Query:" + query + " with : " + ex;
            notifyEmail(error);
            System.err.println(error);
            Logger.getLogger(SE065.class.getName()).log(Level.SEVERE, null, ex);
        } finally {
            query = null;
        }

    }

    //Task#8786 start
    public void setActivityData(String clientLocId){
        String query = "";
        try {
            Statement stmt = con.createStatement();            
            Statement stUpdate = con.createStatement();
            ResultSet rs = null;
            String pdEndDt = getLastDateOfMonth();
            
            query = "SELECT /*SE065*/ quantity FROM `activity` WHERE Clientlocid = '"+clientLocId+"' and periodenddate = '"+pdEndDt+"' and activitytype = 'LATLO'";
            System.out.println(getDateTime() + ":setActivityData: query 1:" + query);
            rs = stmt.executeQuery(query);
            
            if(rs.next()){
                int qty = rs.getInt("quantity");
                qty ++;
                query = "UPDATE /*SE065*/ activity set  quantity = '"+qty+"'  WHERE Clientlocid = '"+clientLocId+"' and periodenddate = '"+pdEndDt+"' and activitytype = 'LATLO'";
                System.out.println(getDateTime() + ":setActivityData: query 2:" + query);
                stUpdate.executeUpdate(query);
            }else{
                query = "INSERT /*SE065*/ into activity (clientlocid,activitytype,period,periodenddate,reccreatets,quantity) VALUES('"+clientLocId+"','LATLO','M','"+pdEndDt+"',NOW(),'1')";
                System.out.println(getDateTime() + ":setActivityData: query 3:" + query);
                stUpdate.executeUpdate(query);
            }
            pdEndDt = null;    
        } catch (Exception ex) {
			error = getDateTime() + ":  : setActivityData : Error occured : last Query:" + query + " with : " + ex;
            notifyEmail(error);
            System.err.println(error);
            Logger.getLogger(SE065.class.getName()).log(Level.SEVERE, null, ex);
        }
        finally {
            query = null;
        }
                 
    }
    
	public String getLastDateOfMonth(){
        DateFormat df = new SimpleDateFormat("yyyy-MM-dd");
        Calendar cal = Calendar.getInstance();
        Date dt = cal.getTime();
        String dtStr = df.format(dt);
        int res = cal.getActualMaximum(Calendar.DATE);       
        dtStr = dtStr.substring(0,8) + res;
        System.out.println("getLastDateOfMonth dtstr=" + dtStr);
		return dtStr;
    }
    //Task#8786 End
	
	public static void main(String[] args) {
        String query = "";
        try {

            SE065 se065 = new SE065();
            String authId = "", authToken = "";
            Statement stmt = null, stmt1 = null;
            ResultSet rs = null, rs2 = null;
            int delayTime = 1;
            boolean runningFlag = true;
            while (runningFlag) {

                /*for local connectoin/
                con = SE065.connect();
                /**/

 /*for remote connectoin*/
                se065.createConnection();
                /**/
                stmt = con.createStatement();
                stmt1 = con.createStatement();
                rs2 = stmt1.executeQuery("SELECT /*SE065*/ charvar FROM cvt.system WHERE recid = 'SP065'");
                if (rs2.next()) {
                    String startflag = rs2.getString("charvar");
                    if (startflag.equals("Y")) {
                        System.out.println("running flag=Y");

                        query = "SELECT /*SE065*/ strvar  FROM `system` WHERE `recid` = 'SSKEY'";
                        System.out.println(getDateTime() + ":main: query 1 :" + query);
                        rs = stmt.executeQuery(query);
                        if (rs.next()) {
                            authId = rs.getString("strvar");
                        }

                        query = "SELECT /*SE065*/ strvar  FROM `system` WHERE `recid` = 'SSTOK'";
                        System.out.println(getDateTime() + ":main: query 2 :" + query);
                        rs = stmt.executeQuery(query);
                        if (rs.next()) {
                            authToken = rs.getString("strvar");
                        }

                        se065.startProcess(authId, authToken);

                        rs = stmt.executeQuery("SELECT /*SE065*/ intvar FROM cvt.system WHERE recid = 'SE065' AND (intvar is not null OR intvar <> 0)");
                        if (rs.next()) {
                            delayTime = rs.getInt("intvar");
                        }
                        con.close();
                        System.out.println("delaytime:" + delayTime);
                        Thread.sleep(1000 * delayTime);
                    } else {
                        runningFlag = false;
                        System.out.println("running flag=N");
                    }
                } else {
                    runningFlag = false;
                    System.out.println("running flag=N");
                }
                if (!con.isClosed()) {
                    con.close();
                }
            }

        } catch (Exception ex) {
            SE065 se065 = new SE065();
            String err = getDateTime() + ":  : main : Error occured : last Query:" + query + " with : " + ex;
            se065.notifyEmail(err);
            System.err.println(err);
            Logger.getLogger(SE065.class.getName()).log(Level.SEVERE, null, ex);
        } finally {
            query = null;
        }
    }

    private static String getDateTime() {//it is utility method which occure  in every log statement. So to avoid object making at every occrance we use static method
        DateFormat dateFormat = new SimpleDateFormat("yyyy/MM/dd HH:mm:ss");
        TimeZone timeZone = TimeZone.getDefault();
        dateFormat.setTimeZone(timeZone.getTimeZone("America/Los_Angeles"));
        return dateFormat.format(new Date());
    }

    public void notifyEmail(String strError) {
        try {
            Connection connRep = con;
            String fromEmail = null, toemail = null;
            fromEmail = "noreply@teakwce.com";

            System.out.println(getDateTime() + " MAIL : body is---" + strError);
            Statement st = connRep.createStatement();
            ResultSet rs;

            toemail = "";
            String query = "SELECT /*SE065*/ p.email FROM cvt.person p,cvt.personlink pl,cvt.notifyperson np WHERE np.groupcode = '" + groupCode + "' AND np.personlinkid = pl.recid AND p.recid = pl.personid AND (p.email IS NOT NULL AND length(trim(p.email))>0)";
            System.out.println(getDateTime() + ": MAIL : " + query);
            rs = st.executeQuery(query);
            while (rs.next()) {
                toemail += rs.getString("email") + ",";
            }

            if (!"".equalsIgnoreCase(toemail) && null != toemail) {
                toemail = toemail.substring(0, (toemail.length() - 1));
            }

            if ((!"".equalsIgnoreCase(toemail) && null != toemail)) {
                File file = new File("/usr/local/twce/se/cm/Mailing.mail");
                boolean exists = file.exists();
                boolean success;
                if (!exists) {
                    // It returns false if File or directory does not exist
                    success = file.createNewFile();
                    System.out.println(getDateTime() + "  : MAIL : Searching directory Created. " + exists);
                } else {
                    // It returns true if File or directory exists
                    success = file.delete();
                }

                if (success) {
                    FileWriter f = new FileWriter(file);
                    f.write("Mime-Version: 1.0\n");
                    f.write("Content-Type: text/html\n");
                    f.write("Content-Transfer-Encoding: 8BIT\n");
                    if (!"".equalsIgnoreCase(toemail) && null != toemail) {
                        f.write("To:" + toemail + "\n");
                    } else {
                        f.write("To: \n");
                    }

                    f.write("From:" + fromEmail + "\n");
                    f.write("Subject: " + subject + "\n");
                    f.write("\n\n");
                    f.write(" " + strError + "\n\n");
                    f.close();

                    String op;
                    String command[] = {"sh", "-c", "/usr/sbin/sendmail -t < /usr/local/twce/se/cm/Mailing.mail", ""};
                    Process child = Runtime.getRuntime().exec(command);
                    InputStream in = child.getInputStream();
                    int c;
                    int j = 1;
                    char[] opc;
                    opc = new char[1000];
                    while ((c = in.read()) != -1) {
                        opc[j] = ((char) c);
                        System.out.print((char) c);
                        j = j + 1;
                    }
                    in.close();
                    op = new String(opc).substring(1, j);
                    System.out.println(getDateTime() + " MAIL :Op is---" + op);
                }
            }
            rs.close();
            st.close();
        } catch (Exception add) {
            strError = getDateTime() + ": PushMail : NotifyEmail Error In  - : NotifyEmail - \n" + add;
            System.out.println(getDateTime() + " : **************************************************");
            System.out.println(getDateTime() + " MAIL : Error Occured while sending mail:" + add);
            System.out.println(getDateTime() + " : **************************************************");
        }
    }

    public void sendBadAddressMail() {
        String query = "";
        try {
            Map<String, String> errorAddress = new HashMap<>();
            Statement stmt1 = con.createStatement();
            Statement stUpdate = con.createStatement();
            ResultSet rs1 = null;

            query = "SELECT /*SE065*/\n"
                    + "    rl.barcode,\n"
                    + "    glq.clientlocid,\n"
                    + "    glq.custaddressid,\n"
                    + "    glq.outgoingaddress,\n"
                    + "    glq.recordtype,\n"
                    + "    glq.dpvmatchcode,\n"
                    + "    glq.dpvfootnotes,\n"
                    + "    glq.footnotes\n"
                    + "FROM\n"
                    + "   gpslocqueue glq,\n"
                    + "   routelink rl,\n"
                    + "   locationlink ll\n"
                    + "WHERE\n"
                    + " glq.status='C'\n"
                    + " and ll.locationid=glq.clientlocid\n"
                    + " and ll.companyid=rl.clientid\n"
                    + " and glq.customerlocid != 0 and glq.customerlocid !='' and  glq.customerlocid IS NOT NULL "//Task#8541
                    + " and rl.locationid=glq.customerlocid";

            System.out.println(getDateTime() + ":sendBadAddressMail query 1:" + query);
            rs1 = stmt1.executeQuery(query);
            while (rs1.next()) {
                String barcode = "", clientLocId = "", custAddressId = "", outgoingAddress = "", dpvMatchCode = "", dpvFootNotes = "", footNotes = "", recordType = "";
                String message = "", message1 = "", dpvFootnoteString = "", recordTypeString = "";
                barcode = rs1.getString("barcode");
                clientLocId = rs1.getString("clientlocid");
                custAddressId = rs1.getString("custaddressid");
                outgoingAddress = rs1.getString("outgoingaddress");
                dpvMatchCode = rs1.getString("dpvmatchcode");
                dpvFootNotes = rs1.getString("dpvfootnotes");
                footNotes = rs1.getString("footnotes");
                recordType = rs1.getString("recordtype");
                System.out.println("dpvMatchCode=" + dpvMatchCode);
                System.out.println("dpvFootNotes=" + dpvFootNotes);
                System.out.println("footNotes=" + footNotes);
                System.out.println("recordType=" + recordType);
                message = "<b>Address:</b> " + outgoingAddress + "  (Acct#" + barcode + ")\n <br> <b>Response:</b> ";
                recordTypeString = getRecordTypeString(recordType);
                if (recordTypeString.isEmpty()) {
                    dpvFootnoteString = getDpvFootNotesString(dpvFootNotes);
                    message += dpvFootnoteString + "<br>";
                } else {
                    message += recordTypeString + "<br>";
                }
                System.out.println("error for Addressid:" + custAddressId + " :: massage  =" + message);

                if (errorAddress.containsKey(clientLocId)) {
                    message1 = errorAddress.get(clientLocId);
                    errorAddress.remove(clientLocId);
                    message = message1 + " <br> " + message;
                    errorAddress.put(clientLocId, message);
                } else {
                    errorAddress.put(clientLocId, message);
                }
            }
            //Task#8541 start
            query = "SELECT /*SE065*/\n"
                    + "    glq.clientlocid,\n"
                    + "    glq.custaddressid,\n"
                    + "    glq.outgoingaddress,\n"
                    + "    glq.recordtype,\n"
                    + "    glq.dpvmatchcode,\n"
                    + "    glq.dpvfootnotes,\n"
                    + "    glq.footnotes\n"
                    + "FROM\n"
                    + "   gpslocqueue glq\n"
                    + "WHERE\n"
                    + " glq.status='C'\n"
                    + " and (glq.customerlocid = 0 || glq.customerlocid ='' ||  glq.customerlocid IS  NULL )";

            System.out.println(getDateTime() + ":sendBadAddressMail query 2:" + query);
            rs1 = stmt1.executeQuery(query);
            while (rs1.next()) {
                String clientLocId = "", custAddressId = "", outgoingAddress = "", dpvMatchCode = "", dpvFootNotes = "", footNotes = "", recordType = "";
                String message = "", message1 = "", dpvFootnoteString = "", recordTypeString = "";

                clientLocId = rs1.getString("clientlocid");
                custAddressId = rs1.getString("custaddressid");
                outgoingAddress = rs1.getString("outgoingaddress");
                dpvMatchCode = rs1.getString("dpvmatchcode");
                dpvFootNotes = rs1.getString("dpvfootnotes");
                footNotes = rs1.getString("footnotes");
                recordType = rs1.getString("recordtype");
                System.out.println("dpvMatchCode=" + dpvMatchCode);
                System.out.println("dpvFootNotes=" + dpvFootNotes);
                System.out.println("footNotes=" + footNotes);
                System.out.println("recordType=" + recordType);

                message = "<b>Address:</b> " + outgoingAddress + "\n <br> <b>Response:</b> ";
                recordTypeString = getRecordTypeString(recordType);
                if (recordTypeString.isEmpty()) {
                    dpvFootnoteString = getDpvFootNotesString(dpvFootNotes);
                    message += dpvFootnoteString + "<br>";
                } else {
                    message += recordTypeString + "<br>";
                }
                System.out.println("error for StoreRetrieve.recid:" + custAddressId + " :: massage  =" + message);

                if (errorAddress.containsKey(clientLocId)) {
                    message1 = errorAddress.get(clientLocId);
                    errorAddress.remove(clientLocId);
                    message = message1 + " <br> " + message;
                    errorAddress.put(clientLocId, message);
                } else {
                    errorAddress.put(clientLocId, message);
                }
            }
            //Task#8541 End
            if (!errorAddress.isEmpty()) {
                for (Map.Entry<String, String> entry : errorAddress.entrySet()) {
                    String clientLocId = entry.getKey();
                    String massage = entry.getValue();
                    StringBuilder eb = new StringBuilder();
                    eb.append("<html>\n");
                    eb.append("<head>\n");
                    eb.append(" <meta http-equiv=\"content-type\" content=\"text/html; charset=UTF-8\">\n");
                    eb.append("</head>\n");
                    eb.append("<body>\n");
                    eb.append(" We are not able to get a valid lat/long for addresses below, Please modify them so that we can try again: <br>\n");
                    eb.append(massage);
                    eb.append("</body>\n");
                    eb.append("</html>\n");
                    String emailBody = eb.toString();
                    eb.setLength(1);
                    System.out.println("emailBody=\n" + emailBody);
                    sendEmailToClient(clientLocId, emailBody);
                    query = "UPDATE /*SE065*/ gpslocqueue set status='B' WHERE clientlocid='" + clientLocId + "' and status='C'";
                    System.out.println(getDateTime() + ":sendBadAddressMail query 2:" + query);
                    stUpdate.executeUpdate(query);
                }
            }
        } catch (Exception ex) {
            error = getDateTime() + ": PushMail : sendBadAddressMail Error In  - : sendBadAddressMail - \n" + ex;
            notifyEmail(error);
            System.err.println(error);
            Logger.getLogger(SE065.class.getName()).log(Level.SEVERE, null, ex);
        } finally {
            query = null;
        }

    }

    public String getRecordTypeString(String recordType) {
        String errString = "";
        switch (recordType) {
            case "G":
                errString += "Address is General Delivery type.(for mail to be held at local post offices.)  \n <br>";
                break;
            case "P":
                errString += "Address is a Post Office Box. \n <br>";
                break;
            case "R":
                errString += "Address is Rural Route or Highway Contract type. \n <br>";
                break;
            default:
                break;
        }
        return errString;
    }

    public String getDpvMatchCodeString(String dpvMatchCode) {
        String errString = "";
        if (dpvMatchCode == null || dpvMatchCode.isEmpty()) {
            errString += "address does not have a ZIP Code and a +4 add-on code, or the address has already been determined to be Not Deliverable \n <br>";
        }
        return errString;
    }

    public String getDpvFootNotesString(String dpvFootNotes) {
        String errString = "";
        int length = dpvFootNotes.length();
        ArrayList<String> parts = new ArrayList<>();
        System.out.println("parts of dpvFootNotes::" + parts);
        for (int i = 0; i < length; i++) {
            parts.add(dpvFootNotes.substring(i, Math.min(length, i + 2)));
        }

        if (parts.contains("AA")) {
            errString += "Address is invalid. (City/state/ZIP + street don't match.) \n <br>";
        }
        if (parts.contains("A1")) {
            errString += "Primary number (e.g., house number) is missing. \n <br>";
        }
        if (parts.contains("BB")) {
            errString += " ZIP+4 matched; confirmed entire address; address is valid. \n <br>";
        }
        if (parts.contains("CC")) {
            errString += " Confirmed address by dropping secondary (apartment, suite, etc.) information.\n <br>";
        }
        if (parts.contains("F1")) {
            errString += "Matched to military or diplomatic address. \n <br>";
        }
        if (parts.contains("G1")) {
            errString += "Matched to general delivery address. \n <br>";
        }
        if (parts.contains("M1")) {
            errString += "Primary number (e.g., house number) is missing. \n <br>";
        }
        if (parts.contains("M3")) {
            errString += "Primary number (e.g., house number) is invalid. \n <br>";
        }
        if (parts.contains("N1")) {
            errString += "Confirmed with missing secondary information; address is valid but it also needs a secondary number (apartment, suite, etc.). \n <br>";
        }
        if (parts.contains("PB")) {
            errString += "Confirmed as a PO BOX street style address. \n <br>";
        }
        if (parts.contains("P1")) {
            errString += "PO, RR, or HC box number is missing. \n <br>";
        }
        if (parts.contains("P3")) {
            errString += "PO, RR, or HC box number is invalid. \n <br>";
        }
        if (parts.contains("RR")) {
            errString += "Confirmed address with private mailbox (PMB) info. \n <br>";
        }
        if (parts.contains("R1")) {
            errString += "Confirmed address without private mailbox (PMB) info. \n <br>";
        }
        if (parts.contains("R7")) {
            errString += "Confirmed as a valid address that doesn't currently receive US Postal Service street delivery. \n <br>";
        }
        if (parts.contains("U1")) {
            errString += "Matched a unique ZIP Code. \n <br>";
        }
        return errString;
    }

    public String getFootNotesString(String footNotes) {
        String errString = "";
        if (footNotes.contains("C#")) {
            errString += "Invalid city/state/ZIP \n <br>";
        }
        if (footNotes.contains("F#")) {
            errString += "Address not found \n <br>";
        }
        if (footNotes.contains("H#")) {
            errString += "Missing secondary number \n <br>";
        }
        if (footNotes.contains("I#")) {
            errString += "Insufficient/ incorrect address data \n <br>";
        }
        if (footNotes.contains("S#")) {
            errString += "Bad secondary address \n <br>";
        }
        if (footNotes.contains("V#")) {
            errString += "Unverifiable city / state \n <br>";
        }
        if (footNotes.contains("W#")) {
            errString += "Invalid delivery address \n <br>";
        }
        if (footNotes.contains("S#")) {
            errString += "Bad secondary address \n <br>";
        }
        if (footNotes.contains("S#")) {
            errString += "Bad secondary address \n <br>";
        }
        return errString;
    }

    public void sendEmailToClient(String clientLocId, String err) {
        String query = "";
        Statement stmt3 = null;
        ResultSet rs3 = null;

        try {
            query = "SELECT /*SE065*/ p.email FROM person p,personlink pl,notifygrouplink ngl,notifyperson np "
                    + " WHERE ngl.locationid = '" + clientLocId + "' AND	ngl.groupcode = \"BAD\"  "
                    + " AND np.groupcode = ngl.groupcode  "
                    + " AND np.personlinkid = pl.recid AND pl.locationid = '" + clientLocId + "' "
                    + " AND p.recid = pl.personid "
                    + " AND (p.email IS NOT NULL AND length(trim(p.email))>0)";
           
            stmt3 = con.createStatement();
            rs3 = stmt3.executeQuery(query);
            System.out.println(getDateTime() + ": SE039 : Query - 143:" + query);
            while (rs3.next()) {
                String email = rs3.getString("email");
                try {
                    File file = new File("/usr/local/twce/se/cm/test.mail");
                    boolean exists = file.exists();
                    if (!exists) {
                        // It returns false if File or directory does not exist
                        System.err.println(getDateTime() + ": SE039 : 18 : Searching directory not exists.");
                    } else {
                        // It returns true if File or directory exists
                        boolean success = file.delete();
                        if (success) {
                            FileWriter f = new FileWriter("/usr/local/twce/se/cm/test.mail");
                            f.write("Mime-Version: 1.0\n");
                            f.write("Content-Type: text/html\n");
                            f.write("Content-Transfer-Encoding: 8BIT\n");
                            f.write("To:" + email + "\n");
                            f.write("Subject:Bad Delivery Addresses found\n");
                            f.write("\n" + err + "\n\n");
                            f.close();
                        }
                    }
                    System.out.println(processCommand("sh", "-c", "/usr/sbin/sendmail -t < /usr/local/twce/se/cm/test.mail", ""));
//                    System.out.println(getDateTime() + ": SE065 : 19 : Mail send for incomplete Address:");
                } catch (Exception e) {
                    System.err.println(getDateTime() + ": SE065 : 20 : Error Occured while sending mail:" + e);
                }
            }
            rs3.close();
            stmt3.close();
        } catch (Exception add) {
            System.err.println(getDateTime() + ": SE065 : 21 : Error Occured while sending mail:" + add);
        } finally {
            query = null;
            stmt3 = null;
            rs3 = null;
        }
    }

    public String processCommand(String cmd, String p01, String p02, String p03) {
        String op = new String();
        try {
            String command[]
                    = {
                        cmd, p01, p02, p03
                    };
            Process child = Runtime.getRuntime().exec(command);
            InputStream in = child.getInputStream();
            int c;
            int j = 1;
            char[] opc;
            opc = new char[1000];
            while ((c = in.read()) != -1) {
                opc[j] = ((char) c);
                System.out.print((char) c);
                j = j + 1;
            }
            in.close();
            op = new String(opc).substring(1, j);
        } catch (IOException e) {
            op = new String("ERROR");;
        }
        return op.toString();
    }
}
