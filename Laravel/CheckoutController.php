<?
/*
    Version History
    ====================================
    Version.    Modi.Date       Modi.By    Description
    1.2         2022-02-14      Nimesh     Task#9234 : Please fix an issue due to which its not filtering the Ship Engine Service Codes and package types properly based on data listed in carrierinfo.txt file properly.
	1.1         2022-02-02      Nimesh     Task#9225 : Implement the integration of SendGrid API's into our "Email Send" process
    1.0         2022-02-02      Admin      Program registered under version history.
    ====================================
*/
?>
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Defeecalc;
use App\Models\Entity;
use App\Models\Entityaddress;
use App\Models\EntityProfile;
use App\Models\Financialxtnctl;
use App\Models\Floor;
use App\Models\Inventory;
use App\Models\Inventoryxtn;
use App\Models\LocalZipcodes;
use App\Models\Orderdetail;
use App\Models\Orders;
use App\Models\PaymentMethods;
use App\Models\PhantomRoute;
use App\Models\Product_variants;
use App\Models\Route;
use App\Models\Routehops;
use App\Models\Routehopsdetail;
use App\Models\Stagingroute;
use App\Models\Standardroute;
use App\Models\System;
use App\Models\Taxrates;
use App\Models\User;
use DB;
use Illuminate\Http\Request;
use Mail;

class CheckoutController extends Controller
{
    public $curDate;
    public $curDateTime;
    public function __construct()
    {
        $this->curDate = date("Y-m-d");
        $this->curDateTime = date('Y-m-d H:i:s');
    }

    public function checkoutstepone(Request $request)
    {
        $curDate = $this->curDate;
        $input = $request->all();
        $uid = $request->input('uid');
        $url = $request->input('url');
        $redirect = "";
      
        $entitydata = Entity::select('primary_address_id', 'entity_id', 'billingaddressid')
            ->where('user_id', '=', $uid)
            ->first();
        if (isset($entitydata)) {
            $primary_address_id = $entitydata->primary_address_id;
            $entity_id = $entitydata->entity_id;
            $billing_address_id = $entitydata->billingaddressid;
            $shipping_method = '';
            $entity_profile_id = 0;

            $param = array();
            $param['uid'] = $uid;
            $responses = callApi("post", $param, "getCartTotalItem");
            $result = $responses['data'];

            $shippinginfo = '';
            $paymentinfo = '';
            if (isset($result[0]['shippinginfo'])) {
                $shippinginfo = $result[0]['shippinginfo'];
            }
            if (isset($result[0]['paymentinfo'])) {
                $paymentinfo = $result[0]['paymentinfo'];
            }
            if ($shippinginfo == '' && $paymentinfo == '') {
                $orderdata = Orders::from('orders as o')
                    ->where('o.customer_id', '=', $entity_id)
                    ->select('o.order_remark', 'o.payment_method')
                    ->orderBy('o.order_id', 'desc')->first();
                if (isset($orderdata)) {
                    $order_remark = explode(';', $orderdata->order_remark);
                    if (isset($order_remark[0])) {
                        $primary_address_id = $order_remark[0];
                    }

                    if (isset($order_remark[1])) {
                        $shipping_method = $order_remark[1];
                    }

                    if (isset($order_remark[2])) {
                        $entity_profile_id = $order_remark[2];
                    }
                    $payment_method = $orderdata->payment_method;
                }
            } elseif ($shippinginfo != '' && $paymentinfo != '') {
                if ($url != 'revieworder' && $url != 'deliveryoptionselect') {
                    $redirect = 'checkoutstepfour';
                    $response = array();
                    $response['addressData'] = '';
                    $response['primary_address_id'] = 0;
                    $response['billing_address_id'] = 0;
                    $response['redirect'] = $redirect;

                    return response()->json([
                        "success" => "1",
                        "status" => "200",
                        "message" => "Redirect to step four",
                        "data" => $response,
                    ], 200);
                }
            }
        }

        $shipping_address_id = 0;
        $shipping_address_id = DB::table('cart')->where('user_id', $uid)->value('shipping_address_id');
        if ($shipping_address_id > 0) {
            if ($url != 'cart') {
                $primary_address_id = $shipping_address_id;
            }

        }
        $addressData = Entityaddress::select('entity_address_id', 'name', DB::raw('CONCAT_WS(", ", NULLIF(address1, ""), NULLIF(address2, "")) as address'), 'address1', 'address2', 'city', 'state', 'postalcode', 'primaryphone')
            ->where('entity_id', '=', $entity_id)
            ->where(function ($q) use ($curDate) {
                $q->where('endeffdt')
                    ->orwhere('endeffdt', '=', '0000-00-00')
                    ->orwhere('endeffdt', '>', $curDate);
            })
            ->orderBy('entity_address_id', 'DESC')
            ->get();

        $shippinginfo = '';
        if (isset($orderdata)) {
            if ($shipping_method != '') {
                $shippinginfo = '~~~~' . $shipping_method;
                $ep_data = EntityProfile::select('entity_profile_id', 'profileid', 'paymentprofileid', 'nameonacct', 'expmmyy', 'reference', 'card_type')
                    ->where('entity_profile_id', '=', $entity_profile_id)
                    ->where('active', '=', 'C')
                    ->where('paymentprofileid', '!=', '0')
                    ->where(function ($q) use ($curDate) {
                        $q->where('endeffdt')
                            ->orwhere('endeffdt', '=', '0000-00-00')
                            ->orwhere('endeffdt', '>', $curDate);
                    })
                    ->first();
                $paymentinfo = '';
                if (isset($ep_data)) {
                    $reference = substr($ep_data['reference'], 12, 16);
                    if ($payment_method == 'PayPal') {
                        $paymentinfo = $ep_data['entity_profile_id'] . '~' . $ep_data['profileid'] . '~' . $ep_data['paymentprofileid'] . '~' . $ep_data['card_type'];
                    } else {
                        $paymentinfo = $ep_data['entity_profile_id'] . '~' . $ep_data['profileid'] . '~' . $ep_data['paymentprofileid'] . '~' . $ep_data['card_type'] . ' ending in ' . $reference;
                    }

                    $cartarr = array("shipping_address_id" => $primary_address_id, "billing_address_id" => $billing_address_id, "shippinginfo" => $shippinginfo, "paymentinfo" => $paymentinfo);
                    $test = updateCartinfo($cartarr, $uid);

                    $redirect = 'checkoutstepfour';
                    $response = array();
                    $response['addressData'] = '';
                    $response['primary_address_id'] = 0;
                    $response['billing_address_id'] = 0;
                    $response['redirect'] = $redirect;

                    return response()->json([
                        "success" => "1",
                        "status" => "200",
                        "message" => "Redirect to step four",
                        "data" => $response,
                    ], 200);
                }
            } //END if($shipping_method != '')
        } //END if(isset($orderdata))

        $response = array();
        $response['addressData'] = $addressData;
        $response['primary_address_id'] = $primary_address_id;
        $response['billing_address_id'] = $billing_address_id;
        $response['redirect'] = '';

        return response()->json([
            "success" => "1",
            "status" => "200",
            "message" => "Step One Data get successfull",
            "data" => $response,
        ], 200);
    }

    public function checkoutstepone_submit(Request $request)
    {
        $input = $request->all();
        $entity_address_id = $request->input('entity_address_id');
        $uid = $request->input('uid');

        $entity_id = Entityaddress::where('entity_address_id', $entity_address_id)->value('entity_id');

        $e_data = Entity::select('entity_id', 'billingaddressid')->where('entity_id', $entity_id)->first();

        $billingaddressid = 0;
        if (!is_null($e_data)) {
            $billingaddressid = $e_data->billingaddressid;
            if (!is_numeric($billingaddressid)) {
                $billingaddressid = 0;
            }
        }
        
        if ($billingaddressid == 0) {
            Entity::where('entity_id', $entity_id)->update(array('billingaddressid' => $entity_address_id));
            $billingaddressid = $entity_address_id;
        }

        $cartarr = array("shipping_address_id" => $entity_address_id, "billing_address_id" => $billingaddressid);
        $test = updateCartinfo($cartarr, $uid);

        return response()->json([
            "success" => "1",
            "status" => "200",
            "message" => "Step One Post successfull",
            "data" => array(),
        ], 200);
    }

    public function checkoutsteptwo(Request $request)
    {
        $input = $request->all();
        $uid = $request->input('uid');

        $param = array();
        $param['uid'] = $uid;
        $responses = callApi("post", $param, "getCartTotalItem");
        $cartdata = $responses['data'];

        $total_prod_amt = 0;
        $totalWeight = 0;
        $DEFEE_charvar = System::getSystemval('DEFEE', 'charvar');
        if ($DEFEE_charvar == '') {
            $DEFEE_charvar = 'O';
        }

        if ($DEFEE_charvar == 'I') {
            $total_prod_amt = count($cartdata);
        } else {
            foreach ($cartdata as $cartItem) {
				$cart_variant_id = $cartItem['variant_id'];
                $total_prod_amt += $cartItem['qty'] * $cartItem['sale_price'];
			}
        }
		
		foreach ($cartdata as $cartItem) {
				$cartvariant = Product_variants::where('variant_id', '=', $cartItem['variant_id'])->select('weight')->first();
				$weight = $cartvariant->weight;
				if($weight == '' || $weight == 0)
			    $totalWeight = 120 * $cartItem['qty'];
			    else
				$totalWeight = $weight * $cartItem['qty'];
					
        }
		
        $val_SHKEY = System::getSystemval('SHKEY', 'strvar');
        $shipping_address_id = $cartdata[0]['shipping_address_id'];

        $shippingData = Entityaddress::select('entity_address_id', 'name', 'address1', 'address2', 'city', 'state', 'postalcode', 'primaryphone')
            ->where('entity_address_id', '=', $shipping_address_id)
            ->first();
        $shipping_name = $shippingData->name;
        $shipping_address1 = $shippingData->address1;
        $shipping_address2 = $shippingData->address2;
        $shipping_city = $shippingData->city;
        $shipping_state = $shippingData->state;
        $shipping_primaryphone = $shippingData->primaryphone;
        $shipping_postalcode = $shippingData->postalcode;
        $localdelivery = LocalZipcodes::where('postalcode', '=', $shipping_postalcode)->count();
        $shippinginfo = array();
        if ($localdelivery) {
            $delivefess = Defeecalc::get_deliveryfees($total_prod_amt);
            $shippinginfo[0] = $delivefess;
            $shippinginfo[1] = date('l m/d \b\y h:i A', strtotime("+2 days"));
        } else {
            $shipping_from = Route::from("route as r")
                ->join('entity as e', 'e.entity_id', '=', 'r.depot_entity_id')
                ->join('entityaddress as ea', 'e.primary_address_id', '=', 'ea.entity_address_id')
                ->select('ea.entity_address_id', 'ea.name as pname', 'ea.address1', 'ea.address2', 'ea.city', 'ea.state', 'ea.postalcode', 'ea.primaryphone', 'e.name as cname')
                ->where('r.type', 'OC')
                ->first();

            $shipping_from_pname = $shipping_from->pname;
            $shipping_from_cname = $shipping_from->cname;
            $shipping_from_address1 = $shipping_from->address1;
            $shipping_from_address2 = $shipping_from->address2;
            $shipping_from_city = $shipping_from->city;
            $shipping_from_state = $shipping_from->state;
            $shipping_from_primaryphone = $shipping_from->primaryphone;
            $shipping_from_postalcode = $shipping_from->postalcode;
			
			$carrierFilteArray = GetCarrierInfo();
			$curl = curl_init();
            curl_setopt_array($curl, array(
                CURLOPT_URL => 'https://api.shipengine.com/v1/carriers',
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_ENCODING => '',
                CURLOPT_MAXREDIRS => 10,
                CURLOPT_TIMEOUT => 0,
                CURLOPT_FOLLOWLOCATION => true,
                CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
                CURLOPT_CUSTOMREQUEST => 'GET',
                CURLOPT_HTTPHEADER => array(
                    "API-Key: $val_SHKEY",
                    'Content-Type: application/json',
                ),
            ));

            $response = curl_exec($curl);
            $carrierArr = json_decode($response, true);
            curl_close($curl);
            $carrierlist = array();
            $packageinfo = '';
			$service_codeinfo = '';
			
			if (count($carrierArr['errors']) == 0) {
				
            foreach ($carrierArr as $carriers) {
                foreach ($carriers as $carriersInfo) {
					$carrier_name = $carriersInfo['friendly_name'];
					$carrierlist[$carriersInfo['carrier_id']] = $carriersInfo['carrier_id'];
					if(isset($carrierFilteArray[$carrier_name]))
					{
						
						foreach($carrierFilteArray[$carrier_name] as $carrierinfoarr => $carrierfilterdata)
						{
						
							$carrierinfo = explode('~',$carrierinfoarr);
							$service_codes = $carrierinfo[0];
							$package_type = $carrierinfo[1];
							
							if(!is_numeric($package_type) && $package_type != '')
							{
								if($packageinfo == "")
								$packageinfo = '"package_types": [ "'.$package_type.'"';
								else
								$packageinfo .= ',"'.$package_type.'"';	
							}
							if($service_codeinfo == "")
							$service_codeinfo = '"service_codes": [ "'.$service_codes.'"';
							else
							$service_codeinfo .= ',"'.$service_codes.'"';
							
						}

					}

                }
				
                break;
            }
			}
			if($packageinfo != '')
			$packageinfo .= '],';
		   if($service_codeinfo != '')
			$service_codeinfo .= ']';
		 
            $carrierstr = '"' . implode('","', $carrierlist) . '"';
            //$carrierstr = '"se-631575","se-631576","se-631577"';
           
            $curl = curl_init();
            curl_setopt_array($curl, array(
                CURLOPT_URL => 'https://api.shipengine.com/v1/rates',
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_ENCODING => '',
                CURLOPT_MAXREDIRS => 10,
                CURLOPT_TIMEOUT => 0,
                CURLOPT_FOLLOWLOCATION => true,
                CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
                CURLOPT_CUSTOMREQUEST => 'POST',
                CURLOPT_POSTFIELDS => '{
			  "rate_options": {
				"carrier_ids": [
				   ' . $carrierstr . '
				],
				' . $packageinfo . '
				' .$service_codeinfo . '
			  },
			  "shipment": {
				"validate_address": "no_validation",
				"ship_to": {
					  "name": "' . $shipping_name . '",
					  "phone": "' . $shipping_primaryphone . '",
					  "address_line1": "' . $shipping_address1 . '",
					  "address_line2": "' . $shipping_address2 . '",
					  "city_locality": "' . $shipping_city . '",
					  "state_province": "' . $shipping_state . '",
					  "postal_code": "' . $shipping_postalcode . '",
					  "country_code": "US",
					  "address_residential_indicator": "no"
				},
				"ship_from": {
				  "company_name": "' . $shipping_from_pname . '",
				  "name": "' . $shipping_from_cname . '",
				  "phone": "' . $shipping_from_primaryphone . '",
				  "address_line1": "' . $shipping_from_address1 . '",
				  "address_line2": "' . $shipping_from_address2 . '",
				  "city_locality": "' . $shipping_from_city . '",
				  "state_province": "' . $shipping_from_state . '",
				  "postal_code": "' . $shipping_from_postalcode . '",
				  "country_code": "US",
				  "address_residential_indicator": "no"
				},
				"packages": [
				  {
					"weight": {
					  "value": "'.$totalWeight.'",
					  "unit": "gram"
					 }
				  }
				]
			  }
			}',
                CURLOPT_HTTPHEADER => array(
                    "API-Key: $val_SHKEY",
                    'Content-Type: application/json',
                ),
            ));

            $response = curl_exec($curl);
            $re = json_decode($response, true);
			
            curl_close($curl);
			if (!isset($re['errors'])) {
				
                foreach ($re as $rate_response) {
                    foreach ($rate_response as $rates) {
						usort($rates, function($a, $b) {
							return $a['shipping_amount']['amount'] - $b['shipping_amount']['amount'];
					   });
						foreach ($rates as $ratesinfo) {
							
                            $carrier_name = $ratesinfo['carrier_friendly_name'];
							$service_code = $ratesinfo['service_code'];
							$package_type = $ratesinfo['package_type'];
						    if(isset($carrierFilteArray[$carrier_name][$service_code.'~'.$package_type]))
							{
                               $shippinginfo[$carrier_name][$ratesinfo['rate_id']]['service_type'] = $carrierFilteArray[$carrier_name][$service_code.'~'.$package_type]['carrier_service_type'];
								$shippinginfo[$carrier_name][$ratesinfo['rate_id']]['shipping_amount'] = $ratesinfo['shipping_amount']['amount'];
								$shippinginfo[$carrier_name][$ratesinfo['rate_id']]['delivery_days'] = $ratesinfo['delivery_days'];
								$shippinginfo[$carrier_name][$ratesinfo['rate_id']]['estimated_delivery_date'] = date('l m/d \b\y h:i A', strtotime($ratesinfo['estimated_delivery_date']));
								$shippinginfo[$carrier_name][$ratesinfo['rate_id']]['carrier_delivery_days'] = $ratesinfo['carrier_delivery_days'];
								$shippinginfo[$carrier_name][$ratesinfo['rate_id']]['carrier_id'] = $ratesinfo['carrier_id'];
								$shippinginfo[$carrier_name][$ratesinfo['rate_id']]['service_code'] = $ratesinfo['service_code'];
								$shippinginfo[$carrier_name][$ratesinfo['rate_id']]['package_type'] = $ratesinfo['package_type'];
							}
                        }
                        break;
                    }
                    break;
                }
            }

        }
        
		$response = array();
        $response['shippinginfo'] = $shippinginfo;
        $response['localdelivery'] = $localdelivery;
        return response()->json([
            "success" => "1",
            "status" => "200",
            "message" => "Step Two Data get successfull",
            "data" => $response,
        ], 200);
    }

    public function checkoutsteptwo_submit(Request $request)
    {
        $input = $request->all();
        $shippinginfo = $request->input('shippinginfo');
        $uid = $request->input('uid');

        $cartarr = array("shippinginfo" => $shippinginfo);
        updateCartinfo($cartarr, $uid);

        return response()->json([
            "success" => "1",
            "status" => "200",
            "message" => "Step Two Post successfull",
            "data" => array(),
        ], 200);

    }
    
    public function checkoutstepthree_submit(Request $request)
    {
        $input = $request->all();
        $paymentinfo = $request->input('paymentinfo');
        $uid = $request->input('uid');

        $cartarr = array("paymentinfo" => $paymentinfo);
        updateCartinfo($cartarr, $uid);
        return response()->json([
            "success" => "1",
            "status" => "200",
            "message" => "Step Three Post successfull",
            "data" => array(),
        ], 200);
    }

    public function checkoutstepfour(Request $request)
    {
        $curDate = $this->curDate;
        $input = $request->all();
        $uid = $request->input('uid');

        $param = array();
        $param['uid'] = $uid;
        $responses = callApi("post", $param, "getCartTotalItem");
        $result = $responses['data'];
        $shippingdata = array();
        $paymentdata = array();
        $billingaddressData = array();
        $shippingaddressData = array();
        $addressData = array();
        $tax = 0;
        $tax_rates_id = 0;
        $total_prod_amt = 0;
		$totalWeight = 0;
        $prod_variant_id = array();
        $delivefess = 0;
        if (count($result) > 0) {
            $shippinginfo = $result[0]['shippinginfo'];
            $shippingdata = explode("~", $shippinginfo);

            $paymentinfo = $result[0]['paymentinfo'];
            $paymentdata = explode("~", $paymentinfo);

            $billing_address_id = $result[0]['billing_address_id'];
            $billingaddressData = Entityaddress::select('entity_address_id', 'name', DB::raw('CONCAT_WS(", ", NULLIF(address1, ""), NULLIF(address2, "")) as address'), 'address1', 'address2', 'city', 'state', 'postalcode', 'primaryphone')
                ->where('entity_address_id', '=', $billing_address_id)
                ->first();

            $shipping_address_id = $result[0]['shipping_address_id'];
            $shippingaddressData = Entityaddress::select('entity_address_id', 'name', DB::raw('CONCAT_WS(", ", NULLIF(address1, ""), NULLIF(address2, "")) as address'), 'address1', 'address2', 'city', 'state', 'postalcode', 'primaryphone')
                ->where('entity_address_id', '=', $shipping_address_id)
                ->first();
			
            $shipping_name = $shippingaddressData->name;
            $shipping_address1 = $shippingaddressData->address1;
            $shipping_address2 = $shippingaddressData->address2;
            $shipping_city = $shippingaddressData->city;
            $shipping_state = $shippingaddressData->state;
            $shipping_postalcode = $shippingaddressData->postalcode;
            $shipping_primaryphone = $shippingaddressData->primaryphone;

            $shippingaddressData = Entityaddress::select('entity_address_id', 'name', DB::raw('CONCAT_WS(", ", NULLIF(address1, ""), NULLIF(address2, "")) as address'), 'address1', 'address2', 'city', 'state', 'postalcode', 'primaryphone')
                ->where('entity_address_id', '=', $shipping_address_id)
                ->first();
            $prod_variant_id = array();
            foreach ($result as $cartItem) {
                $order_subtotal = $cartItem['qty'] * $cartItem['sale_price'];
                $total_prod_amt += $order_subtotal;
                $prod_variant_id[] = $cartItem['variant_id'];
				
				$cartvariant = Product_variants::where('variant_id', '=', $cartItem['variant_id'])->select('weight')->first();
				$weight = $cartvariant->weight;
				if($weight == '' || $weight == 0)
			    $totalWeight = 120 * $cartItem['qty'];
			    else
				$totalWeight = $weight * $cartItem['qty'];
            }

            //Calculate Delivery Fee
            $DEFEE_charvar = System::getSystemval('DEFEE', 'charvar');
            if ($DEFEE_charvar == '') {
                $DEFEE_charvar = 'O';
            }

            if ($DEFEE_charvar == 'I') {
                $amt = count($result);
            } else {
                $amt = $total_prod_amt;
            }

            /*####*/
            $shipping_from = Route::from("route as r")
                ->join('entity as e', 'e.entity_id', '=', 'r.depot_entity_id')
                ->join('entityaddress as ea', 'e.primary_address_id', '=', 'ea.entity_address_id')
                ->select('ea.entity_address_id', 'ea.name as pname', 'ea.address1', 'ea.address2', 'ea.city', 'ea.state', 'ea.postalcode', 'ea.primaryphone', 'e.name as cname')
                ->where('r.type', 'OC')
                ->first();

            $shipping_from_pname = $shipping_from->pname;
            $shipping_from_cname = $shipping_from->cname;
            $shipping_from_address1 = $shipping_from->address1;
            $shipping_from_address2 = $shipping_from->address2;
            $shipping_from_city = $shipping_from->city;
            $shipping_from_state = $shipping_from->state;
            $shipping_from_primaryphone = $shipping_from->primaryphone;
            $shipping_from_postalcode = $shipping_from->postalcode;
            /*####*/

            $localdelivery = LocalZipcodes::where('postalcode', '=', $shipping_postalcode)
                ->count();

            $shipinfo = '';
            if ($localdelivery) {
                $delivefess = Defeecalc::get_deliveryfees($amt);
                $shipinfo = '1~Local Delivery~' . date('l m/d \b\y h:i A', strtotime("+2 days")) . '~' . $delivefess . '~~~~';

            } else {
                $delivefess = $shippingdata[3];
                $carrier_id = trim($shippingdata[4]);
                $service_code = trim($shippingdata[5]);
                $package_type = trim($shippingdata[6]);
                $packageinfo = '';

                if ($package_type != '') {
                    $packageinfo = '"package_types": [ "' . $package_type . '" ]';
                }

                $val_SHKEY = System::getSystemval('SHKEY', 'strvar');
                $curl = curl_init();
                curl_setopt_array($curl, array(
                    CURLOPT_URL => 'https://api.shipengine.com/v1/rates',
                    CURLOPT_RETURNTRANSFER => true,
                    CURLOPT_ENCODING => '',
                    CURLOPT_MAXREDIRS => 10,
                    CURLOPT_TIMEOUT => 0,
                    CURLOPT_FOLLOWLOCATION => true,
                    CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
                    CURLOPT_CUSTOMREQUEST => 'POST',
                    CURLOPT_POSTFIELDS => '{
						"rate_options": {
							"carrier_ids": [
								"' . $carrier_id . '"
							],
							"service_codes": [
								"' . $service_code . '"
							],
							' . $packageinfo . '
						},
						"shipment": {
							"validate_address": "no_validation",
							"ship_to": {
								"name": "' . $shipping_name . '",
								"phone": "' . $shipping_primaryphone . '",
								"address_line1": "' . $shipping_address1 . '",
								"address_line2": "' . $shipping_address2 . '",
								"city_locality": "' . $shipping_city . '",
								"state_province": "' . $shipping_state . '",
								"postal_code": "' . $shipping_postalcode . '",
								"country_code": "US",
								"address_residential_indicator": "yes"
							},
							"ship_from": {
								"company_name": "' . $shipping_from_pname . '",
								"name": "' . $shipping_from_cname . '",
								"phone": "' . $shipping_from_primaryphone . '",
								"address_line1": "' . $shipping_from_address1 . '",
								"address_line2": "' . $shipping_from_address2 . '",
								"city_locality": "' . $shipping_from_city . '",
								"state_province": "' . $shipping_from_state . '",
								"postal_code": "' . $shipping_from_postalcode . '",
								"country_code": "US",
								"address_residential_indicator": "no"
							},
							"packages": [
								{
									"weight": {
										"value": "'.$totalWeight.'",
										"unit": "gram"
									}
								}
							]
						}
					}',
                    CURLOPT_HTTPHEADER => array(
                        "API-Key: $val_SHKEY",
                        'Content-Type: application/json',
                    ),
                ));

                $response = curl_exec($curl);
                $re = json_decode($response, true);
                curl_close($curl);
				
				$carrierFilteArray = GetCarrierInfo();
				$shipping_error = false;
				
                if (!isset($re['errors'])) {
                    foreach ($re as $rate_response) {
                        foreach ($rate_response as $rates) {
                            foreach ($rates as $ratesinfo) {
								$carrier_name = $ratesinfo['carrier_friendly_name'];
								$service_code = $ratesinfo['service_code'];
							    $package_type = $ratesinfo['package_type'];
						        if(isset($carrierFilteArray[$carrier_name][$service_code.'~'.$package_type]))
								{
								   
									$service_type = $carrierFilteArray[$carrier_name][$service_code.'~'.$package_type]['carrier_service_type'];
									$shipinfo = $ratesinfo['rate_id'] . '~' . $service_type . '~' . date('l m/d \b\y h:i A', strtotime($ratesinfo['estimated_delivery_date'])) . '~' . $ratesinfo['shipping_amount']['amount'] . '~' . $ratesinfo['carrier_id'] . '~' . $ratesinfo['service_code'] . '~' . $ratesinfo['package_type'].'~'.$ratesinfo['carrier_code'];
									$delivefess = $ratesinfo['shipping_amount']['amount'];
								}
								else
								{
								   $shipping_error = true; 
								   break;
								}
                            } //END foreach($rates as $ratesinfo)
                            break;
                        } //END foreach($rate_response as $rates)
                        break;
                    } //END foreach($re as $rate_response)
                } //END if(!isset($re['errors']))
				else
				{
					$shipping_error = true;
				}
					
                if($shipping_error) {
                    //redirect
                    $result = $shippingdata = $shippingaddressData = $paymentdata = $billingaddressData = $tax = $prod_variant_id = $addressData = $delivefess = $helpcontactList = array();
                    $response = array();
                    $response['result'] = $result;
                    $response['shippingdata'] = $shippingdata;
                    $response['shippingaddressData'] = $shippingaddressData;
                    $response['paymentdata'] = $paymentdata;
                    $response['billingaddressData'] = $billingaddressData;
                    $response['tax'] = $tax;
                    $response['prod_variant_id'] = $prod_variant_id;
                    $response['addressData'] = $addressData;
                    $response['delivefess'] = $delivefess;
                    $response['helpcontactList'] = $helpcontactList;

                    #####
                    return response()->json([
                        "success" => "0",
                        "status" => "203",
                        "message" => "Error in shipping option. Redirect to step two",
                        "data" => $response,
                    ], 200);
                }
            }
            if ($shipinfo != '') {
                $cartarr = array("shippinginfo" => $shipinfo,"paymentinfo" => $paymentinfo,"shipping_address_id" => $shipping_address_id,"billing_address_id" => $billing_address_id);

                $shippingdata = explode("~", $shipinfo);
                updateCartinfo($cartarr, $uid);
            }

            //calculate tax
            $char_TAXSR = System::getSystemval('TAXSR', 'charvar');
            if ($char_TAXSR == "") {
                $char_TAXSR = 'L';
            }

            $strvar_TAXSR = System::getSystemval('TAXSR', 'strvar');
            list($apiLoginID, $apiKey) = explode("~", $strvar_TAXSR);

            if ($char_TAXSR == 'L') {
                $taxdetails = Taxrates::get_tax($shipping_address_id, $total_prod_amt, $delivefess);

                $taxdetailsarr = explode('~', $taxdetails);
                $tax = $taxdetailsarr[0];
                $tax_rates_id = $taxdetailsarr[1];
            } //END if ($char_TAXSR == 'L')
            else if ($char_TAXSR == 'T') {

                $db_cart_id = DB::table('cart')->where('user_id', $uid)->value('id');
                $tc_cartID = $db_cart_id . "_" . $uid;

                //Taxcloud Tax calculations API ( https://taxcloud.com/developer )
                // (1) Ping ---> If this call fails, API credentials are questionable.
                $tc_param = array();
                $tc_param['apiLoginID'] = $apiLoginID;
                $tc_param['apiKey'] = $apiKey;
                $responses = fn_callTaxCloudApi("post", $tc_param, "Ping");
                #echo $responses['ResponseType'];
                #prx($responses);
                // Response Type includes:
                // 0 = Error. likely invalid credentials
                // 1 = Warning. Something went wrong.
                // 2 = Informational. Something could be better
                // 3 = Success! You did it!
                if ($responses['ResponseType'] == 3) {
                    //(2) Verify Address --> Verify (hopefully improve) a customer provided delivery address. VERY IMPORTANT for proper tax jurisdiction assessment.
                    $tc_param = array();
                    $tc_param['apiLoginID'] = $apiLoginID;
                    $tc_param['apiKey'] = $apiKey;
                    $tc_param['Address1'] = $shipping_address1;
                    $tc_param['Address2'] = $shipping_address2;
                    $tc_param['City'] = $shipping_city;
                    $tc_param['State'] = $shipping_state;
                    $tc_param['Zip5'] = $shipping_postalcode;
                    $tc_param['Zip4'] = '';
                    $responses = fn_callTaxCloudApi("post", $tc_param, "VerifyAddress");
                    #prx($responses);
                    #VerifyAddressResult.ErrNumber ---> Our response for VerifyAddress is a little odd. If ErrNumber is "0" then there was no error, and ErrDescription will be null. IMORTANT Even if there are errors (the address couldn't be validated/improved) YOU SHOULD PROCEED WITH THE CUSTOMER PROVIDED ADDRESS.

                    // (3) Lookup ---> Lookup is the "workhorse" of our APIs. Determine applicable tax amounts for items being purchased based on a variety of factors.
                    //$cartid = DB::table('cart')->where('user_id', $uid)->value('id');
                    $tc_param = array();
                    $tc_param['apiLoginID'] = $apiLoginID;
                    $tc_param['apiKey'] = $apiKey;
                    $tc_param['customerID'] = $uid;
                    $tc_param['cartID'] = $tc_cartID;
                    $tc_param['deliveredBySeller'] = "false";
                    $tc_param['origin']['Address1'] = $shipping_from_address1;
                    $tc_param['origin']['Address2'] = $shipping_from_address2;
                    $tc_param['origin']['City'] = $shipping_from_city;
                    $tc_param['origin']['State'] = $shipping_from_state;
                    $tc_param['origin']['Zip5'] = $shipping_from_postalcode;
                    $tc_param['origin']['Zip4'] = "";

                    $tc_param['destination']['Address1'] = $shipping_address1;
                    $tc_param['destination']['Address2'] = $shipping_address2;
                    $tc_param['destination']['City'] = $shipping_city;
                    $tc_param['destination']['State'] = $shipping_state;
                    $tc_param['destination']['Zip5'] = $shipping_postalcode;
                    $tc_param['destination']['Zip4'] = "";

                    foreach ($result as $k => $value) {
                        $tc_param['cartItems'][$k]['Index'] = $value['variant_id'];
                        $tc_param['cartItems'][$k]['ItemID'] = $value['variant_id'];
                        $tc_param['cartItems'][$k]['Price'] = $value['sale_price'];
                        $tc_param['cartItems'][$k]['Qty'] = $value['qty'];
                        $tc_param['cartItems'][$k]['TIC'] = '93116';
                        $tc_param['cartItems'][$k]['Tax'] = "";
                    }
                    $s = $k + 1;
                    $tc_param['cartItems'][$s]['Index'] = $s;
                    $tc_param['cartItems'][$s]['ItemID'] = "shipping";
                    $tc_param['cartItems'][$s]['Price'] = $delivefess;
                    $tc_param['cartItems'][$s]['Qty'] = 1;
                    $tc_param['cartItems'][$s]['TIC'] = '10010';
                    $tc_param['cartItems'][$s]['Tax'] = "";

                    $responses = fn_callTaxCloudApi("post", $tc_param, "Lookup");
                    // Response Types include
                    // 0 = Error. Likely invalid API Credentials
                    // 1 = Warning. Something is wrong.
                    // 2 = Informational. Something could be better
                    // 3 = SUCCESS! You did it!
                    if ($responses['ResponseType'] == 3) {
                        $tax_rates_id = $responses['CartID'];
                        $tax = 0;
                        foreach ($responses['CartItemsResponse'] as $k => $v) {
                            $tax += $v['TaxAmount'];
                        }
                    }
                    //prx($responses);

                } //END if($responses['ResponseType'] == 3)

            } //END else if ($char_TAXSR == 'T')
            #exit;

            $entity_id = Entityaddress::where('entity_address_id', $shipping_address_id)->value('entity_id');

            $addressData = Entityaddress::select('entity_address_id', 'name', DB::raw('CONCAT_WS(", ", NULLIF(address1, ""), NULLIF(address2, "")) as address'), 'address1', 'address2', 'city', 'state', 'postalcode', 'primaryphone')
                ->where('entity_id', '=', $entity_id)
                ->where(function ($q) use ($curDate) {
                    $q->where('endeffdt')
                        ->orwhere('endeffdt', '=', '0000-00-00')
                        ->orwhere('endeffdt', '>', $curDate);
                })
                ->orderBy('entity_address_id', 'DESC')
                ->get();
        } //END if(count($result) > 0)
        else {
            return response()->json([
                "success" => "0",
                "status" => "299",
                "message" => "No product in cart",
                "data" => array(),
            ], 200);
        }

        $helpcontactList = array();
        $param = array();
        $responses = callApi("get", $param, "get_helpcontact");
        if ($responses['success'] == 1) {
            $helpcontactList = $responses['data'];
        }

        $response = array();
        $response['result'] = $result;
        $response['shippingdata'] = $shippingdata;
        $response['shippingaddressData'] = $shippingaddressData;
        $response['paymentdata'] = $paymentdata;
        $response['billingaddressData'] = $billingaddressData;
        $response['tax'] = $tax;
        $response['tax_rates_id'] = $tax_rates_id;
        $response['prod_variant_id'] = $prod_variant_id;
        $response['addressData'] = $addressData;
        $response['delivefess'] = $delivefess;
        $response['helpcontactList'] = $helpcontactList;
        //prx($response);
        #####
        return response()->json([
            "success" => "1",
            "status" => "200",
            "message" => "Step Four Data get successfull",
            "data" => $response,
        ], 200);
    }

    public function placeorder(Request $request)
    {
        $curDate = $this->curDate;
        $curDateTime = $this->curDateTime;

        $input = $request->all();
        $uid = $request->input('uid');
        $total_prod_amt = $request->input('total_prod_amt');
        $total_amt = $request->input('total_amt');
        $deliveryfees = $request->input('deliveryfees');
        $tax_amt = $request->input('tax_amt');
        $tax_rates_id = $request->input('tax_rates_id');
        $coupon_discount_amount = $request->input('coupon_discount_amount');
        $address_id = $request->input('address_id');
        $billing_address_id = $request->input('billing_address_id');
        $entity_profile_id = $request->input('entity_profile_id');
        $prod_variant_ary = $request->input('prod_variant_ary');
        $quantityAry = $request->input('quantityAry');
        $shipping_method = $request->input('shipping_method');
        $delivery_est = $request->input('delivery_est');

        if ($uid) {
            $pm_data = PaymentMethods::select('payment_name')
                ->where('payment_gateway', 'CPROC')
                ->where('status', '1')
                ->first();

            if (!isset($pm_data)) {
                $msg = 'Unfortunately, Authorize.net Payment method is inactive So Please change the payment method.';
                $response = array();
                $response["status"] = 'error';
                $response["msg"] = $msg;
                $response["type"] = 'pstatus';
                return response()->json([
                    "success" => "0",
                    "status" => "203",
                    "message" => $msg,
                    "data" => $response,
                ], 200);
            }
            foreach ($prod_variant_ary as $key => $variant_id) {
                $quantity = $quantityAry[$key];

                $prodData = Product_variants::from('product_variants as pv')
                    ->join('product as p', 'p.product_id', '=', 'pv.product_id')
                    ->select('pv.product_id', 'pv.sale_price', 'p.seller_id', 'pv.variant_sku', 'p.product_name', 'pv.variant_barcode', 'p.is_section_zero', 'pv.current_stock')
                    ->where('pv.variant_id', '=', $variant_id)
                    ->where('pv.status', '=', '1')
                    ->first();

                if (!isset($prodData)) {
                    $msg = 'Unfortunately, Few items that you ordered are now Unavailable. Please remove them from your cart as they are no longer available';
                    $response = array();
                    $response["status"] = 'error';
                    $response["msg"] = $msg;
                    $response["type"] = 'pstatus';
                    return response()->json([
                        "success" => "0",
                        "status" => "203",
                        "message" => $msg,
                        "data" => $response,
                    ], 200);
                } else {
                    if ($prodData->is_section_zero == 1 && $quantity > $prodData->current_stock) {
                        $msg = 'Unfortunately, Few items that you ordered are now out-of-stock. Please remove them from your cart as they are no longer available';
                        $response = array();
                        $response["status"] = 'error';
                        $response["msg"] = $msg;
                        $response["type"] = 'pstatus';
                        return response()->json([
                            "success" => "0",
                            "status" => "203",
                            "message" => $msg,
                            "data" => $response,
                        ], 200);
                    }
                }
            } //END foreach ($prod_variant_ary as $key => $variant_id)

            $entity_id = Entity::where('user_id', $uid)->value('entity_id');
            $email = User::where('id', $uid)->value('email');

            $char_NOHND = System::getSystemval('NOHND', 'charvar');
            if ($char_NOHND == "") {
                $char_NOHND = 'N';
            }

            #####################
            //TAX SYSTEM VARIABLE
            $char_TAXSR = System::getSystemval('TAXSR', 'charvar');
            if ($char_TAXSR == "") {
                $char_TAXSR = 'L';
            }
            $strvar_TAXSR = System::getSystemval('TAXSR', 'strvar');
            list($TAX_apiLoginID, $TAX_apiKey) = explode("~", $strvar_TAXSR);
            #####################

            $data = System::select('strvar')
                ->where('system_id', '=', 'CPROC')
                ->first();
            $strvar_CPROC = $authorizenetname = $authorizenetkey = $strValidationMode = "";
            if (!is_null($data)) {
                $strvar_CPROC = $data->strvar;
            }
            if ($strvar_CPROC != '') {
                $arr_strvar_CPROC = explode("~", $strvar_CPROC);
                $authorizenetname = $arr_strvar_CPROC[0];
                $authorizenetkey = $arr_strvar_CPROC[1];
                $strValidationMode = $arr_strvar_CPROC[2];

                $zeroPaymentProfileIdFlag = false;
                $entityprofiledata = EntityProfile::select('profileid', 'paymentprofileid')
                    ->where('entity_profile_id', '=', $entity_profile_id)
                    ->where('entity_id', '=', $entity_id)
                    ->where('type', '!=', 'P')
                    ->first();
                $profileid = 0;
                $paymentprofileid = 0;
                if (!is_null($entityprofiledata)) {
                    $profileid = $entityprofiledata->profileid;
                    $paymentprofileid = $entityprofiledata->paymentprofileid;
                }

                if ($profileid != 0 && $paymentprofileid != 0) {
                    $response = chargeCustomerProfile($profileid, $paymentprofileid, $total_amt, $authorizenetname, $authorizenetkey, $strValidationMode);

                    if ($response != null) {
                        if ($response->getMessages()->getResultCode() == "Ok") {
                            $tresponse = $response->getTransactionResponse();
                            if ($tresponse != null && $tresponse->getMessages() != null) {
                                $tranid = $tresponse->getTransId();
                                $addressData = Entityaddress::from('entityaddress as ea')
                                    ->join('entity as e', 'ea.entity_id', '=', 'e.entity_id')
                                    ->join('users as u', 'e.user_id', '=', 'u.id')
                                    ->select('e.first_name', 'e.last_name', 'u.email', 'ea.address1', 'ea.address2', 'ea.city', 'ea.state', 'ea.postalcode', 'ea.country', 'ea.primaryphone', 'ea.latitude', 'ea.longitude')
                                    ->where('ea.entity_address_id', '=', $address_id)
                                    ->first();
                                $first_name = $addressData->first_name;
                                $last_name = $addressData->last_name;
                                $email = $addressData->email;
                                $address1 = $addressData->address1;
                                $address2 = $addressData->address2;
                                $city = $addressData->city;
                                $state = $addressData->state;
                                $postalcode = $addressData->postalcode;
                                $country = $addressData->country;
                                $primaryphone = $addressData->primaryphone;
                                $latitude = $addressData->latitude;
                                $longitude = $addressData->longitude;

                                $billing_addressData = Entityaddress::from('entityaddress as ea')
                                    ->join('entity as e', 'ea.entity_id', '=', 'e.entity_id')
                                    ->join('users as u', 'e.user_id', '=', 'u.id')
                                    ->select('e.first_name', 'e.last_name', 'u.email', 'ea.address1', 'ea.address2', 'ea.city', 'ea.state', 'ea.postalcode', 'ea.country', 'ea.primaryphone')
                                    ->where('ea.entity_address_id', '=', $billing_address_id)
                                    ->first();

                                $billing_first_name = $billing_addressData->first_name;
                                $billing_last_name = $billing_addressData->last_name;
                                $billing_email = $billing_addressData->email;
                                $billing_address1 = $billing_addressData->address1;
                                $billing_address2 = $billing_addressData->address2;
                                $billing_city = $billing_addressData->city;
                                $billing_state = $billing_addressData->state;
                                $billing_postalcode = $billing_addressData->postalcode;
                                $billing_country = $billing_addressData->country;
                                $billing_primaryphone = $billing_addressData->primaryphone;

                                /*####*/
                                $shipping_from = Route::from("route as r")
                                    ->join('entity as e', 'e.entity_id', '=', 'r.depot_entity_id')
                                    ->join('entityaddress as ea', 'e.primary_address_id', '=', 'ea.entity_address_id')
                                    ->select('ea.entity_address_id', 'ea.name as pname', 'ea.address1', 'ea.address2', 'ea.city', 'ea.state', 'ea.postalcode', 'ea.primaryphone', 'e.name as cname')
                                    ->where('r.type', 'OC')
                                    ->first();

                                $shipping_from_pname = $shipping_from->pname;
                                $shipping_from_cname = $shipping_from->cname;
                                $shipping_from_address1 = $shipping_from->address1;
                                $shipping_from_address2 = $shipping_from->address2;
                                $shipping_from_city = $shipping_from->city;
                                $shipping_from_state = $shipping_from->state;
                                $shipping_from_primaryphone = $shipping_from->primaryphone;
                                $shipping_from_postalcode = $shipping_from->postalcode;
                                /*####*/
                                #Taxcloud
                                if ($char_TAXSR == 'T') {
                                    $db_cart_id = DB::table('cart')->where('user_id', $uid)->value('id');
                                    $tc_cartID = $db_cart_id . "_" . $uid;
                                    // (3) Lookup ---> Lookup is the "workhorse" of our APIs. Determine applicable tax amounts for items being purchased based on a variety of factors.
                                    $tc_param = array();
                                    $tc_param['apiLoginID'] = $TAX_apiLoginID;
                                    $tc_param['apiKey'] = $TAX_apiKey;
                                    $tc_param['customerID'] = $uid;
                                    $tc_param['cartID'] = $tc_cartID;
                                    $tc_param['deliveredBySeller'] = "false";
                                    $tc_param['origin']['Address1'] = $shipping_from_address1;
                                    $tc_param['origin']['Address2'] = $shipping_from_address2;
                                    $tc_param['origin']['City'] = $shipping_from_city;
                                    $tc_param['origin']['State'] = $shipping_from_state;
                                    $tc_param['origin']['Zip5'] = $shipping_from_postalcode;
                                    $tc_param['origin']['Zip4'] = "";

                                    $tc_param['destination']['Address1'] = $address1;
                                    $tc_param['destination']['Address2'] = $address2;
                                    $tc_param['destination']['City'] = $city;
                                    $tc_param['destination']['State'] = $state;
                                    $tc_param['destination']['Zip5'] = $postalcode;
                                    $tc_param['destination']['Zip4'] = "";

                                    foreach ($prod_variant_ary as $k => $variant_id) {
                                        $quantity = $quantityAry[$key];
                                        $prodData = Product_variants::from('product_variants as pv')
                                            ->select('pv.sale_price')
                                            ->where('pv.variant_id', '=', $variant_id)
                                            ->first();
                                        $sale_price = $prodData->sale_price;

                                        $tc_param['cartItems'][$k]['Index'] = $variant_id;
                                        $tc_param['cartItems'][$k]['ItemID'] = $variant_id;
                                        $tc_param['cartItems'][$k]['Price'] = $sale_price;
                                        $tc_param['cartItems'][$k]['Qty'] = $quantity;
                                        $tc_param['cartItems'][$k]['TIC'] = '93116';
                                        $tc_param['cartItems'][$k]['Tax'] = "";
                                    } //END foreach ($prod_variant_ary as $key => $variant_id)
                                    $s = $k + 1;
                                    $tc_param['cartItems'][$s]['Index'] = "shipping";
                                    $tc_param['cartItems'][$s]['ItemID'] = "shipping";
                                    $tc_param['cartItems'][$s]['Price'] = $deliveryfees;
                                    $tc_param['cartItems'][$s]['Qty'] = 1;
                                    $tc_param['cartItems'][$s]['TIC'] = '10010';
                                    $tc_param['cartItems'][$s]['Tax'] = "";

                                    $lookup_response = fn_callTaxCloudApi("post", $tc_param, "Lookup");

                                    $lookup_taxamount_array = array();
                                    if ($lookup_response['ResponseType'] == 3) {
                                        foreach ($lookup_response['CartItemsResponse'] as $k => $v) {
                                            if ($k == 0) {
                                                $lookup_taxamount_array['0'] = $v['TaxAmount'];
                                            } else {
                                                $id = $v['CartItemIndex'];
                                                $lookup_taxamount_array[$id] = $v['TaxAmount'];
                                            }
                                        }
                                    }
                                } //END if ($char_TAXSR == 'T')

                                //Find the ec_phantomroute record nearest to the customer location address latlong
                                $deliveryroute_id = 0;
                                $localdelivery = LocalZipcodes::where('postalcode', '=', $postalcode)->count();
                                if ($localdelivery) {
                                    $phantom_data = PhantomRoute::select('phantomroute_id', 'route_id', DB::raw("((ACOS(SIN( '$latitude' * PI() / 180) * SIN( latitude * PI() / 180) + COS( '$latitude' * PI() / 180) * COS( latitude * PI() / 180 ) * COS( (  '$longitude' - longitude ) * PI() / 180 ) ) * 180 / PI() ) * 60 * 1.1515 ) AS distance"))
                                        ->where(function ($q) use ($curDate) {
                                            $q->where('endeffdt')
                                                ->orwhere('endeffdt', '=', '0000-00-00')
                                                ->orwhere('endeffdt', '>', $curDate);
                                        })
                                        ->having('distance', '>=', '0')
                                        ->orderby('distance')
                                        ->first();
                                    if (!is_null($phantom_data)) {
                                        $deliveryroute_id = $phantom_data->route_id;
                                    }
                                } else {
                                    $deliveryroute_id = Route::where('type', 'OC')
                                        ->where(function ($q) use ($curDate) {
                                            $q->where('endeffdt')
                                                ->orwhere('endeffdt', '=', '0000-00-00')
                                                ->orwhere('endeffdt', '>', $curDate);
                                        })->value('route_id');
                                }

                                $int_OPERA = System::getSystemval('OPERA', 'intvar');
                                $realvar_TEAKP = System::getSystemval('TEAKP', 'realvar');
                                $int_NNROD = System::getNxtSystemintvar('NNORD');

                                $paymentdata = EntityProfile::select('type', 'reference')
                                    ->where('entity_profile_id', '=', $entity_profile_id)
                                    ->where('paymentprofileid', '!=', '0')
                                    ->where('type', '!=', 'P')
                                    ->where(function ($q) use ($curDate) {
                                        $q->where('endeffdt')
                                            ->orwhere('endeffdt', '=', '0000-00-00')
                                            ->orwhere('endeffdt', '>', $curDate);
                                    })
                                    ->first();
                                $pf_type = $paymentdata->type;
                                if ($pf_type == 'C') {
                                    $payment_type = 'Credit Card';
                                } else {
                                    $payment_type = 'Cash on Delivery';
                                }
                                $payment_method = 'Authorize.net';
                                $reference = $paymentdata->reference;
                                $ccinfo = substr($reference, -4);
                                $payment_status = 'Paid';
                                $checkout_type = 'M';
                                $status = 'Pending';

                                EntityProfile::where('entity_id', $entity_id)->update(['active' => 'N']);
                                EntityProfile::where('entity_profile_id', $entity_profile_id)->update(['active' => 'C']);

                                $order_remark = $address_id . ';' . $shipping_method . ';' . $entity_profile_id;

                                //INSERT ec_order
                                $insert_order = new Orders;
                                $insert_order->customer_id = $entity_id;
                                $insert_order->order_no = $int_NNROD;
                                $insert_order->created_at = $curDateTime;
                                $insert_order->updated_at = $curDateTime;
                                $insert_order->sub_total = $total_prod_amt;
                                $insert_order->shipping = $deliveryfees;
                                $insert_order->tax = $tax_amt;
                                $insert_order->coupon_disc = $coupon_discount_amount;
                                $insert_order->order_total = $total_amt;
                                $insert_order->payment_type = $payment_type;
                                $insert_order->payment_method = $payment_method;
                                $insert_order->payment_status = $payment_status;
                                $insert_order->ccinfo = $ccinfo;
                                $insert_order->transaction_info = $tranid;
                                $insert_order->payment_gateway_response = '';
                                $insert_order->order_remark = $order_remark;
                                $insert_order->checkout_type = $checkout_type;
                                $insert_order->status = $status;
                                $insert_order->ship_first_name = $first_name;
                                $insert_order->ship_last_name = $last_name;
                                $insert_order->ship_email = $email;
                                $insert_order->ship_address1 = $address1;
                                $insert_order->ship_address2 = !empty($address2) ? $address2 : '';
                                $insert_order->ship_city = $city;
                                $insert_order->ship_zip = $postalcode;
                                $insert_order->ship_state = $state;
                                $insert_order->ship_country = $country;
                                $insert_order->ship_phone = $primaryphone;
                                $insert_order->bill_first_name = $billing_first_name;
                                $insert_order->bill_last_name = $billing_last_name;
                                $insert_order->bill_email = $billing_email;
                                $insert_order->bill_address1 = $billing_address1;
                                $insert_order->bill_address2 = !empty($billing_address2) ? $billing_address2 : '';
                                $insert_order->bill_city = $billing_city;
                                $insert_order->bill_zip = $billing_postalcode;
                                $insert_order->bill_state = $billing_state;
                                $insert_order->bill_country = $billing_country;
                                $insert_order->bill_phone = $billing_primaryphone;
                                $insert_order->save();
                                $order_id = $insert_order->id;

                                //Taxcloud Tax calculations API
                                if ($char_TAXSR == 'T') {
                                    $tc_param = array();
                                    $tc_param['apiLoginID'] = $TAX_apiLoginID;
                                    $tc_param['apiKey'] = $TAX_apiKey;
                                    $tc_param['customerID'] = $uid;
                                    $tc_param['cartID'] = $tc_cartID;
                                    $tc_param['orderID'] = $int_NNROD;
                                    $tc_param['dateAuthorized'] = $curDateTime;
                                    $tc_param['dateCaptured'] = $curDateTime;

                                    $tc_responses = fn_callTaxCloudApi("post", $tc_param, "AuthorizedWithCapture");
                                    /*
                                if ($tc_responses['ResponseType'] == 0) {
                                $msg = "Error in Taxcloud";
                                $response = array();
                                $response["status"] = 'error';
                                $response["msg"] = $msg;
                                $response["type"] = '';
                                return response()->json([
                                "success" => "0",
                                "status" => "203",
                                "message" => $msg,
                                "data" => $response,
                                ], 200);
                                }
                                 */
                                }

                                #exit;

                                $status = "success";
                                $msg = "Order placed";
                                $type = '';

                                $iteminfo = array();
                                $seller_iteminfo = array();
                                $item = count($prod_variant_ary);
								$param = array();
								$param['uid'] = $uid;
								$responses = callApi("post", $param, "getCartTotalItem");
								$cart = $responses['data'];

                                foreach ($prod_variant_ary as $key => $variant_id) {
                                    $quantity = $quantityAry[$key];

                                    $prodData = Product_variants::from('product_variants as pv')
                                        ->join('product as p', 'p.product_id', '=', 'pv.product_id')
                                        ->select('pv.product_id', 'pv.sale_price', 'p.seller_id', 'pv.variant_sku', 'p.product_name', 'pv.variant_barcode', 'p.is_section_zero', 'pv.current_stock')
                                        ->where('pv.variant_id', '=', $variant_id)
                                        ->first();
                                    $product_id = $prodData->product_id;
                                    $sale_price = $prodData->sale_price;
                                    $seller_id = $prodData->seller_id;
                                    $variant_sku = $prodData->variant_sku;
                                    $product_name = $prodData->product_name;
                                    $variant_barcode = $prodData->variant_barcode;
                                    $is_section_zero = $prodData->is_section_zero;
                                    $current_stock = $prodData->current_stock;
                                    $updated_stock = $current_stock - $quantity;

                                    if ($is_section_zero == '1') {
                                        //update product stock
                                        Product_variants::where('variant_id', '=', $variant_id)->update(['current_stock' => $updated_stock]);
                                    }

                                    $product_price = $sale_price * $quantity;
                                    $iteminfo[$variant_id]['item_name'] = $product_name;
									$iteminfo[$variant_id]['qty'] = $quantity;
									$iteminfo[$variant_id]['sale_price'] = $sale_price;
									$iteminfo[$variant_id]['total_price'] = $product_price;
									
									$getproductinfo = explode('<>',getProductImgWithAttributeInfo($variant_id,$cart));
									$iteminfo[$variant_id]['product_image'] = $getproductinfo[0];
									$iteminfo[$variant_id]['attinfo'] = $getproductinfo[1];
									
									$seller_iteminfo[$seller_id]['iteminfo'][$variant_id]['item_name'] = $product_name;
									$seller_iteminfo[$seller_id]['iteminfo'][$variant_id]['qty'] = $quantity;
									$seller_iteminfo[$seller_id]['iteminfo'][$variant_id]['sale_price'] = $sale_price;
									$seller_iteminfo[$seller_id]['iteminfo'][$variant_id]['total_price'] = $product_price;
									$seller_iteminfo[$seller_id]['iteminfo'][$variant_id]['product_image'] = $getproductinfo[0];
									$seller_iteminfo[$seller_id]['iteminfo'][$variant_id]['attinfo'] = $getproductinfo[1];
									
									if(!isset($seller_iteminfo[$seller_id]['seller_subtotal']))
									$seller_iteminfo[$seller_id]['seller_subtotal'] = 0;	
									$seller_iteminfo[$seller_id]['seller_subtotal'] += $product_price;
									

                                    $prod_proportion = round(($product_price / $total_prod_amt), 2);

                                    $prod_tax = 0;
                                    if ($char_TAXSR == 'T') {
                                        $prod_tax = $lookup_taxamount_array[$variant_id];
                                    } else {
                                        $prod_tax = round($tax_amt * $prod_proportion, 2);
                                    }
									
									
									$seller_iteminfo[$seller_id][$variant_id]['prod_tax'] = $prod_tax;
									if(!isset($seller_iteminfo[$seller_id]['seller_tax']))
									$seller_iteminfo[$seller_id]['seller_tax'] = 0;
									$seller_iteminfo[$seller_id]['seller_tax'] += $prod_tax;
									
									if(!isset($seller_iteminfo[$seller_id]['seller_total']))
									$seller_iteminfo[$seller_id]['seller_total'] = 0;
									$seller_iteminfo[$seller_id]['seller_total'] += $product_price + $prod_tax;
									
                                    $coupon_amt = round($coupon_discount_amount * $prod_proportion, 2);

                                    $binshelf_id = $seller_comm = $inventorylink_id = $from_inv_depot_addr_id = $inventory_id = $inv_entity_id = $inv_qty = $depot_entity_id = 0;
                                    $inv_data = Inventory::from('inventory as i')
                                        ->join('entity as e', 'i.entity_id', '=', 'e.entity_id')
                                        ->join('binshelf as bs', 'i.binshelf_id', '=', 'bs.binshelf_id')
                                        ->join('inventorylink as il', 'bs.inventorylink_id', '=', 'il.inventorylink_id')
                                        ->select('e.seller_comm', 'e.primary_address_id', 'i.binshelf_id', 'bs.inventorylink_id', 'i.inventory_id', 'i.entity_id as inv_entity_id', 'i.quantity as inv_qty', 'il.depot_entity_id')
                                        ->where('i.products_variants_id', '=', $variant_id)
                                        ->where('i.seller_id', '=', $seller_id)
                                        ->where(function ($q) use ($curDate) {
                                            $q->where('e.endeffdt')
                                                ->orwhere('e.endeffdt', '=', '0000-00-00')
                                                ->orwhere('e.endeffdt', '>', $curDate);
                                        })
                                        ->first();
                                    if (!is_null($inv_data)) {
                                        $seller_comm = $inv_data->seller_comm;
                                        $from_inv_depot_addr_id = $inv_data->primary_address_id;
                                        $binshelf_id = $inv_data->binshelf_id;
                                        $inventorylink_id = $inv_data->inventorylink_id;
                                        $inventory_id = $inv_data->inventory_id;
                                        $inv_entity_id = $inv_data->inv_entity_id;
                                        $inv_qty = $inv_data->inv_qty;
                                        $depot_entity_id = $inv_data->depot_entity_id;
                                    }
                                    $seller_comm_amount = round(($product_price * ($seller_comm / 100)), 2);
                                    $teak_amount = round(($product_price * $realvar_TEAKP), 2);

                                    $int_NNBCD = System::getNxtSystemintvar('NNBCD');
                                    $routehops_id = 0;
                                    if ($inv_entity_id == $seller_id) {
                                        $sr_data = Standardroute::select('route_id')
                                            ->where('seller_id', '=', $seller_id)
                                            ->where(function ($q) use ($curDate) {
                                                $q->where('endeffdt')
                                                    ->orwhere('endeffdt', '=', '0000-00-00')
                                                    ->orwhere('endeffdt', '>', $curDate);
                                            })
                                            ->first();
                                        $pickuproute_id = 0;
                                        if (!is_null($sr_data)) {
                                            $pickuproute_id = $sr_data->route_id;
                                        }

                                        $rh_data = Routehops::select('routehops_id')
                                            ->where('type', '=', 'R')
                                            ->where('pickuproute_id', '=', $pickuproute_id)
                                            ->where('deliveryroute_id', '=', $deliveryroute_id)
                                            ->first();
                                        if (!is_null($rh_data)) {
                                            $routehops_id = $rh_data->routehops_id;
                                        }
                                    } else {

                                        $rh_data = Routehops::select('routehops_id')
                                            ->where('type', '=', 'I')
                                            ->where('from_inv_depot_addr_id', '=', $from_inv_depot_addr_id)
                                            ->where('deliveryroute_id', '=', $deliveryroute_id)
                                            ->first();
                                        if (!is_null($rh_data)) {
                                            $routehops_id = $rh_data->routehops_id;
                                        }
                                    }

                                    //INSERT ec_orderdetai
                                    $insert_orderdetail = new Orderdetail;
                                    $insert_orderdetail->order_id = $order_id;
                                    $insert_orderdetail->order_no = $int_NNROD;
                                    $insert_orderdetail->seller_id = $seller_id;
                                    $insert_orderdetail->product_id = $product_id;
                                    $insert_orderdetail->product_sku = $variant_sku;
                                    $insert_orderdetail->product_name = $product_name;
                                    $insert_orderdetail->product_variant = $variant_id;
                                    $insert_orderdetail->product_barcode = $variant_barcode;
                                    $insert_orderdetail->order_detail_barcode = $int_NNBCD;
                                    $insert_orderdetail->product_price = $sale_price;
                                    $insert_orderdetail->quantity = $quantity;
                                    $insert_orderdetail->total_price = $product_price;
                                    $insert_orderdetail->tax = $prod_tax;
                                    $insert_orderdetail->coupon = $coupon_amt;
                                    $insert_orderdetail->seller_comm_amount = $seller_comm_amount;
                                    $insert_orderdetail->shipping_method = $shipping_method;
                                    $insert_orderdetail->status = 'Pending';
                                    $insert_orderdetail->route_hops_id = $routehops_id;
                                    $insert_orderdetail->save();
                                    $order_detail_id = $insert_orderdetail->id;

                                    if ($routehops_id > 0) {
                                        //Get seller_address_id of seller_id
                                        $seller_Data = Entity::from('entity as e')
                                            ->join('entityaddress as ea', function ($join) {
                                                $join->on('e.entity_id', '=', 'ea.entity_id')
                                                    ->whereRaw('ec_e.primary_address_id != ec_ea.entity_address_id');
                                            })
                                            ->select('ea.entity_address_id')
                                            ->where('e.entity_id', '=', $seller_id)
                                            ->where(function ($q) use ($curDate) {
                                                $q->where('ea.endeffdt')
                                                    ->orwhere('ea.endeffdt', '=', '0000-00-00')
                                                    ->orwhere('ea.endeffdt', '>', $curDate);
                                            })
                                            ->first();
                                        if (!is_null($seller_Data)) {
                                            $seller_entityaddr_id = $seller_Data->entity_address_id;
                                        } else {
                                            $seller_entityaddr_id = 0;
                                        }

                                        $rhd_data = Routehopsdetail::select('route_id', 'sequencenumber')
                                            ->where('routehops_id', '=', $routehops_id)
                                            ->get();
                                        foreach ($rhd_data as $key => $value) {
                                            $route_id = $value->route_id;
                                            $sequencenumber = $value->sequencenumber;

                                            //INSERT ec_stagingroute
                                            $insert_sr = new Stagingroute;
                                            $insert_sr->type = 'D';
                                            $insert_sr->route_id = $route_id;
                                            $insert_sr->order_detail_id = $order_detail_id;
                                            $insert_sr->seller_entityaddr_id = $seller_entityaddr_id;
                                            $insert_sr->customer_entityaddr_id = $address_id;
                                            $insert_sr->sequence = $sequencenumber;
                                            $insert_sr->status = 'E';
                                            $insert_sr->save();
                                        }
                                    } //END if ($routehops_id > 0)

                                    //Insert into ec_inventoryxtn
                                    $_status = '';
                                    if ($is_section_zero == '0') {
                                        $_status = 'B';
                                    } else {
                                        $_status = 'P';
                                    }
                                    $ins_invxtn = new Inventoryxtn;
                                    $ins_invxtn->inventorylink_id = $inventorylink_id;
                                    $ins_invxtn->products_variants_id = $variant_id;
                                    $ins_invxtn->order_detail_id = $order_detail_id;
                                    $ins_invxtn->seller_entity_id = $seller_id;
                                    $ins_invxtn->quantity = $quantity;
                                    $ins_invxtn->inout = 'O';
                                    $ins_invxtn->status = $_status;
                                    $ins_invxtn->binshelf_id = $binshelf_id;
                                    $ins_invxtn->inventory_id = $inventory_id;
                                    $ins_invxtn->postedflag = 'N';
                                    $ins_invxtn->save();
                                    $new_invxtn_id = $ins_invxtn->inventoryxtn_id;

                                    $product_cost_amount = round(($product_price - $seller_comm_amount), 2);
                                    $ins_fxc = new Financialxtnctl;
                                    $ins_fxc->xtn_date = $curDateTime;
                                    $ins_fxc->order_id = $order_id;
                                    $ins_fxc->order_detail_id = $order_detail_id;
                                    $ins_fxc->seller_id = $seller_id;
                                    $ins_fxc->customer_id = $entity_id;
                                    $ins_fxc->product_id = $product_id;
                                    $ins_fxc->quantity = $quantity;
                                    $ins_fxc->tax_rates_id = $tax_rates_id;
                                    $ins_fxc->xtn_type = 'O';
                                    $ins_fxc->product_cost_amount = $product_cost_amount;
                                    $ins_fxc->seller_payment_status = 'P';
                                    $ins_fxc->tax_amount = $prod_tax;
                                    $ins_fxc->tax_payment_status = 'P';
                                    $ins_fxc->product_sale_amount = $product_price;
                                    $ins_fxc->delivery_amount = '';
                                    $ins_fxc->teak_amount = $teak_amount;
                                    $ins_fxc->teak_payment_status = 'P';
                                    $ins_fxc->save();

                                    //Task#9214 Starts
                                    if ($inv_entity_id != $seller_id && $char_NOHND =='Y') {
                                        $final_qty = $inv_qty - $quantity;
                                        if($final_qty > 0) {
                                            Inventory::where('inventory_id', '=', $inventory_id)->update(['quantity' => $final_qty]);
                                        } else {
                                            Inventory::where('inventory_id', '=', $inventory_id)->update(['quantity' => $final_qty, 'endeffdt' => $curDate]);
                                        }

                                        Inventoryxtn::where('inventoryxtn_id', '=', $new_invxtn_id)->update(['users_id' => $uid, 'postedflag' => 'Y', 'status' => 'C']);

                                        
                                        $staging_data = Stagingroute::select('stagingroute_id')
                                            ->where('order_detail_id', '=', $order_detail_id)
                                            ->orderBy('sequence', 'ASC')->first();
                                        $stagingroute_id = 0;
                                        if (isset($staging_data)) {
                                            $stagingroute_id = $staging_data->stagingroute_id;
                                        }
                                        if($stagingroute_id > 0) {
                                            Stagingroute::where('stagingroute_id', '=', $stagingroute_id)->update(['status' => 'I']);
                                        }

                                        $ins_floor = new Floor;
                                        $ins_floor->entity_id = $depot_entity_id;
                                        $ins_floor->order_detail_id = $order_detail_id;
                                        $ins_floor->status = 'O';
                                        $ins_floor->inventory_xtn_id = $new_invxtn_id;
                                        $ins_floor->reccreatedt = $curDateTime;
                                        $ins_floor->save();

                                    }//END if ($inv_entity_id != $seller_id && $char_NOHND =='Y')
                                    //Task#9214 Ends


                                }//END foreach ($prod_variant_ary as $key => $variant_id)

                                if ($deliveryfees > 0) {
                                    $ins_fxc = new Financialxtnctl;
                                    $ins_fxc->xtn_date = $curDateTime;
                                    $ins_fxc->order_id = $order_id;
                                    $ins_fxc->customer_id = $entity_id;
                                    $ins_fxc->xtn_type = 'S';
                                    $ins_fxc->delivery_amount = $deliveryfees;
                                    if ($char_TAXSR == 'T') {
                                        $ins_fxc->tax_amount = $lookup_taxamount_array[0];
                                    }
                                    $ins_fxc->save();
                                } //END if ($deliveryfees > 0)
                                
                                DB::table("cart")->where('user_id', $uid)->delete();
                                $success = 'success';
                                $msg = 'Order placed Successfully';
								
								$infoarray = array();
								$infoarray['first_name'] = $first_name;
								$infoarray['last_name'] = $last_name;
								$infoarray['address1'] = $address1;
								$infoarray['city'] = $city;
								$infoarray['state'] = $state;
								$infoarray['postalcode'] = $postalcode;
								$infoarray['primaryphone'] = $primaryphone;
								$infoarray['total_prod_amt'] = $total_prod_amt;
								$infoarray['deliveryfees'] = $deliveryfees;
								$infoarray['tax_amt'] = $tax_amt;
								$infoarray['total_amt'] = $total_amt;
								
								sendmail_sendgrid($iteminfo,$seller_iteminfo,$email,$infoarray,$int_NNROD);
								
                                //$email = session()->get('userDetail')['email'];
                                //$email = 'nimesh@teaksi.com';
                                // Mail::send('web.email-orderconfirm', ['order_id' => $order_id, 'order_no' => $int_NNROD, 'item' => $item, 'price' => $total_prod_amt, 'shipping' => $deliveryfees, 'tax' => $tax_amt, 'coupon' => $coupon_discount_amount, 'total' => $total_amt, 'addressData' => $addressData, 'delivery_est' => $delivery_est], function ($m) use ($email) {
                                // $m->to($email)->subject('Order confirmation');
                                // });
								/*
                                $email_temp = DB::table("email_templates")->where('title', 'Order confirmation')->
                                    select('title', 'subject', 'mail_body')->first();
                                //prx($email_temp);
                                if (!is_null($email_temp)) {
                                    $title = $email_temp->title;
                                    $subject = $email_temp->subject;
                                    $mail_body = $email_temp->mail_body;
                                    $mail_body = str_replace('{$price}', $total_prod_amt, $mail_body);
                                    $mail_body = str_replace('{$order_no}', $int_NNROD, $mail_body);
                                    $mail_body = str_replace('{$price}', $total_prod_amt, $mail_body);
                                    $mail_body = str_replace('{$shipping}', $deliveryfees, $mail_body);

                                    $mail_body = str_replace('{$item}', $item, $mail_body);
                                    $mail_body = str_replace('{$tax}', $tax_amt, $mail_body);
                                    $mail_body = str_replace('{$coupon}', $coupon_discount_amount, $mail_body);
                                    $mail_body = str_replace('{$total}', $total_amt, $mail_body);
                                    // this will replace {{username}} with $data['username']

                                    // Mail::raw($mail_body, function ($message) use($subject) {
                                    // $message->to('nimesh@teaksi.com')
                                    // ->subject($subject);
                                    // });

                                    Mail::send('web.email-orderconfirm1', ['mail_body' => $mail_body], function ($m) use ($email) {
                                        $m->to($email)->subject('Order confirmation');
                                    });
                                }
								*/
								
									
                                $msg = "Order placed Successfully";
                                $response = array();
                                $response["status"] = 'success';
                                $response["msg"] = $msg;
                                $response["type"] = '';
                                $response["ORDER_ID"] = $order_id;
                                $response["ORDER_NO"] = $int_NNROD;
                                return response()->json([
                                    "success" => "1",
                                    "status" => "200",
                                    "message" => $msg,
                                    "data" => $response,
                                ], 200);
                                ####
                            } //END if ($tresponse != null && $tresponse->getMessages() != null)
                            else {
                                $msg = "Transaction Failed";
                                $response = array();
                                $response["status"] = 'error';
                                $response["msg"] = $msg;
                                $response["type"] = '';
                                return response()->json([
                                    "success" => "0",
                                    "status" => "203",
                                    "message" => $msg,
                                    "data" => $response,
                                ], 200);
                            }
                        } //END if($response->getMessages()->getResultCode() == "Ok")
                        else {
                            $msg = "Transaction Failed";
                            $response = array();
                            $response["status"] = 'error';
                            $response["msg"] = $msg;
                            $response["type"] = '';
                            return response()->json([
                                "success" => "0",
                                "status" => "203",
                                "message" => $msg,
                                "data" => $response,
                            ], 200);
                        }
                    } //END if ($response != null)
                    else {
                        $msg = "Transaction Failed";
                        $response = array();
                        $response["status"] = 'error';
                        $response["msg"] = $msg;
                        $response["type"] = '';
                        return response()->json([
                            "success" => "0",
                            "status" => "203",
                            "message" => $msg,
                            "data" => $response,
                        ], 200);
                    }
                } //END if ($profileid != 0 && $paymentprofileid != 0)
                else {
                    $msg = 'Payment profile not exist';
                    $response = array();
                    $response["status"] = 'error';
                    $response["msg"] = $msg;
                    $response["type"] = '';
                    return response()->json([
                        "success" => "0",
                        "status" => "203",
                        "message" => $msg,
                        "data" => $response,
                    ], 200);
                }
            } //END if ($strvar_CPROC != '')
            else {
                $msg = 'Payment profile not exist';
                $response = array();
                $response["status"] = 'error';
                $response["msg"] = $msg;
                $response["type"] = '';
                return response()->json([
                    "success" => "0",
                    "status" => "203",
                    "message" => $msg,
                    "data" => $response,
                ], 200);
            }
        } else {
            $response = array();
            $response["status"] = 'error';
            $response["msg"] = "Please login";
            $response["type"] = '';
            return response()->json([
                "success" => "0",
                "status" => "203",
                "message" => "Please login",
                "data" => $response,
            ], 200);
        }

    }
    public function paypal_placeorder(Request $request)
    {
        $curDate = $this->curDate;
        $curDateTime = $this->curDateTime;

        $input = $request->all();

        $uid = $request->input('uid');
        $total_prod_amt = $request->input('total_prod_amt');
        $total_amt = $request->input('total_amt');
        $deliveryfees = $request->input('deliveryfees');
        $tax_amt = $request->input('tax_amt');
        $tax_rates_id = $request->input('tax_rates_id');
        $coupon_discount_amount = $request->input('coupon_discount_amount');
        $address_id = $request->input('address_id');
        $billing_address_id = $request->input('billing_address_id');
        $entity_profile_id = $request->input('entity_profile_id');
        $prod_variant_ary = $request->input('prod_variant_ary');
        $quantityAry = $request->input('quantityAry');
        $shipping_method = $request->input('shipping_method');
        $delivery_est = $request->input('delivery_est');
        $tranid = $request->input('paypal_order_id');
        $paypal_capture_id = $request->input('paypal_capture_id');
        $payment_profile_id = $request->input('payment_profile_id');
        $paypal_email_address = $request->input('paypal_email_address');
        $entity_id = Entity::where('user_id', $uid)->value('entity_id');
        $email = User::where('id', $uid)->value('email');

        #####################
        //TAX SYSTEM VARIABLE
        $char_TAXSR = System::getSystemval('TAXSR', 'charvar');
        if ($char_TAXSR == "") {
            $char_TAXSR = 'L';
        }
        $strvar_TAXSR = System::getSystemval('TAXSR', 'strvar');
        list($TAX_apiLoginID, $TAX_apiKey) = explode("~", $strvar_TAXSR);
        #####################

        $char_NOHND = System::getSystemval('NOHND', 'charvar');
        if ($char_NOHND == "") {
            $char_NOHND = 'N';
        }

        if ($entity_profile_id == '') {
            $entity_profile_id = 0;
        }

        $entityprofiledata = EntityProfile::select('profileid', 'paymentprofileid')
            ->where('entity_profile_id', '=', $entity_profile_id)
            ->where('entity_id', '=', $entity_id)
            ->where('type', '=', 'P')
            ->first();
        $paymentprofileid = 0;
        if (!is_null($entityprofiledata)) {
            $paymentprofileid = $entityprofiledata->paymentprofileid;
        }

        if ($paymentprofileid !== $payment_profile_id) {

            $paypalprofiledata = EntityProfile::select('entity_profile_id')
                ->where('paymentprofileid', '=', $payment_profile_id)
                ->where('entity_id', '=', $entity_id)
                ->where('type', '=', 'P')
                ->first();
            if (!is_null($paypalprofiledata)) {
                $entity_profile_id = $paypalprofiledata->entity_profile_id;
            } else {
                $ep_data = new EntityProfile;
                $ep_data->entity_id = $entity_id;
                $ep_data->paymentprofileid = $payment_profile_id;
                $ep_data->reference = $paypal_email_address;
                $ep_data->type = 'P';
                $ep_data->card_type = 'PayPal';
                $ep_data->save();
                $entity_profile_id = $ep_data->id;
            }
        }
        $addressData = Entityaddress::from('entityaddress as ea')
            ->join('entity as e', 'ea.entity_id', '=', 'e.entity_id')
            ->join('users as u', 'e.user_id', '=', 'u.id')
            ->select('e.first_name', 'e.last_name', 'u.email', 'ea.address1', 'ea.address2', 'ea.city', 'ea.state', 'ea.postalcode', 'ea.country', 'ea.primaryphone', 'ea.latitude', 'ea.longitude')
            ->where('ea.entity_address_id', '=', $address_id)
            ->first();

        $first_name = $addressData->first_name;
        $last_name = $addressData->last_name;
        $email = $addressData->email;
        $address1 = $addressData->address1;
        $address2 = $addressData->address2;
        $city = $addressData->city;
        $state = $addressData->state;
        $postalcode = $addressData->postalcode;
        $country = $addressData->country;
        $primaryphone = $addressData->primaryphone;
        $latitude = $addressData->latitude;
        $longitude = $addressData->longitude;

        $billing_addressData = Entityaddress::from('entityaddress as ea')
            ->join('entity as e', 'ea.entity_id', '=', 'e.entity_id')
            ->join('users as u', 'e.user_id', '=', 'u.id')
            ->select('e.first_name', 'e.last_name', 'u.email', 'ea.address1', 'ea.address2', 'ea.city', 'ea.state', 'ea.postalcode', 'ea.country', 'ea.primaryphone')
            ->where('ea.entity_address_id', '=', $billing_address_id)
            ->first();

        $billing_first_name = $billing_addressData->first_name;
        $billing_last_name = $billing_addressData->last_name;
        $billing_email = $billing_addressData->email;
        $billing_address1 = $billing_addressData->address1;
        $billing_address2 = $billing_addressData->address2;
        $billing_city = $billing_addressData->city;
        $billing_state = $billing_addressData->state;
        $billing_postalcode = $billing_addressData->postalcode;
        $billing_country = $billing_addressData->country;
        $billing_primaryphone = $billing_addressData->primaryphone;

        /*####*/
        $shipping_from = Route::from("route as r")
            ->join('entity as e', 'e.entity_id', '=', 'r.depot_entity_id')
            ->join('entityaddress as ea', 'e.primary_address_id', '=', 'ea.entity_address_id')
            ->select('ea.entity_address_id', 'ea.name as pname', 'ea.address1', 'ea.address2', 'ea.city', 'ea.state', 'ea.postalcode', 'ea.primaryphone', 'e.name as cname')
            ->where('r.type', 'OC')
            ->first();

        $shipping_from_pname = $shipping_from->pname;
        $shipping_from_cname = $shipping_from->cname;
        $shipping_from_address1 = $shipping_from->address1;
        $shipping_from_address2 = $shipping_from->address2;
        $shipping_from_city = $shipping_from->city;
        $shipping_from_state = $shipping_from->state;
        $shipping_from_primaryphone = $shipping_from->primaryphone;
        $shipping_from_postalcode = $shipping_from->postalcode;
        /*####*/
        #Taxcloud
        if ($char_TAXSR == 'T') {
            $db_cart_id = DB::table('cart')->where('user_id', $uid)->value('id');
            $tc_cartID = $db_cart_id . "_" . $uid;
            // (3) Lookup ---> Lookup is the "workhorse" of our APIs. Determine applicable tax amounts for items being purchased based on a variety of factors.
            $tc_param = array();
            $tc_param['apiLoginID'] = $TAX_apiLoginID;
            $tc_param['apiKey'] = $TAX_apiKey;
            $tc_param['customerID'] = $uid;
            $tc_param['cartID'] = $tc_cartID;
            $tc_param['deliveredBySeller'] = "false";
            $tc_param['origin']['Address1'] = $shipping_from_address1;
            $tc_param['origin']['Address2'] = $shipping_from_address2;
            $tc_param['origin']['City'] = $shipping_from_city;
            $tc_param['origin']['State'] = $shipping_from_state;
            $tc_param['origin']['Zip5'] = $shipping_from_postalcode;
            $tc_param['origin']['Zip4'] = "";

            $tc_param['destination']['Address1'] = $address1;
            $tc_param['destination']['Address2'] = $address2;
            $tc_param['destination']['City'] = $city;
            $tc_param['destination']['State'] = $state;
            $tc_param['destination']['Zip5'] = $postalcode;
            $tc_param['destination']['Zip4'] = "";

            foreach ($prod_variant_ary as $k => $variant_id) {
                $quantity = $quantityAry[$k];
                $prodData = Product_variants::from('product_variants as pv')
                    ->select('pv.sale_price')
                    ->where('pv.variant_id', '=', $variant_id)
                    ->first();
                $sale_price = $prodData->sale_price;

                $tc_param['cartItems'][$k]['Index'] = $variant_id;
                $tc_param['cartItems'][$k]['ItemID'] = $variant_id;
                $tc_param['cartItems'][$k]['Price'] = $sale_price;
                $tc_param['cartItems'][$k]['Qty'] = $quantity;
                $tc_param['cartItems'][$k]['TIC'] = '93116';
                $tc_param['cartItems'][$k]['Tax'] = "";
            } //END foreach ($prod_variant_ary as $key => $variant_id)
            $s = $k + 1;
            $tc_param['cartItems'][$s]['Index'] = "shipping";
            $tc_param['cartItems'][$s]['ItemID'] = "shipping";
            $tc_param['cartItems'][$s]['Price'] = $deliveryfees;
            $tc_param['cartItems'][$s]['Qty'] = 1;
            $tc_param['cartItems'][$s]['TIC'] = '10010';
            $tc_param['cartItems'][$s]['Tax'] = "";

            $lookup_response = fn_callTaxCloudApi("post", $tc_param, "Lookup");

            $lookup_taxamount_array = array();
            if ($lookup_response['ResponseType'] == 3) {
                foreach ($lookup_response['CartItemsResponse'] as $k => $v) {
                    if ($k == 0) {
                        $lookup_taxamount_array['0'] = $v['TaxAmount'];
                    } else {
                        $id = $v['CartItemIndex'];
                        $lookup_taxamount_array[$id] = $v['TaxAmount'];
                    }
                }
            }
        } //END if ($char_TAXSR == 'T')

        //Find the ec_phantomroute record nearest to the customer location address latlong
        $deliveryroute_id = 0;
        $localdelivery = LocalZipcodes::where('postalcode', '=', $postalcode)->count();
        if ($localdelivery) {
            $phantom_data = PhantomRoute::select('phantomroute_id', 'route_id', DB::raw("((ACOS(SIN( '$latitude' * PI() / 180) * SIN( latitude * PI() / 180) + COS( '$latitude' * PI() / 180) * COS( latitude * PI() / 180 ) * COS( (  '$longitude' - longitude ) * PI() / 180 ) ) * 180 / PI() ) * 60 * 1.1515 ) AS distance"))
                ->where(function ($q) use ($curDate) {
                    $q->where('endeffdt')
                        ->orwhere('endeffdt', '=', '0000-00-00')
                        ->orwhere('endeffdt', '>', $curDate);
                })
                ->having('distance', '>=', '0')
                ->orderby('distance')
                ->first();
            if (!is_null($phantom_data)) {
                $deliveryroute_id = $phantom_data->route_id;
            }
        } else {
            $deliveryroute_id = Route::where('type', 'OC')
                ->where(function ($q) use ($curDate) {
                    $q->where('endeffdt')
                        ->orwhere('endeffdt', '=', '0000-00-00')
                        ->orwhere('endeffdt', '>', $curDate);
                })->value('route_id');
        }

        $int_OPERA = System::getSystemval('OPERA', 'intvar');
        $realvar_TEAKP = System::getSystemval('TEAKP', 'realvar');
        $int_NNROD = System::getNxtSystemintvar('NNORD');

        $payment_type = "";
        $payment_method = 'PayPal';
        $reference = $paypal_email_address;
        $ccinfo = "";
        $payment_status = 'Paid';
        $checkout_type = 'M';
        $status = 'Pending';

        EntityProfile::where('entity_id', $entity_id)->update(['active' => 'N']);
        EntityProfile::where('entity_profile_id', $entity_profile_id)->update(['active' => 'C']);

        $order_remark = $address_id . ';' . $shipping_method . ';' . $entity_profile_id;

        //INSERT ec_order
        $insert_order = new Orders;
        $insert_order->customer_id = $entity_id;
        $insert_order->order_no = $int_NNROD;
        $insert_order->created_at = $curDateTime;
        $insert_order->updated_at = $curDateTime;
        $insert_order->sub_total = $total_prod_amt;
        $insert_order->shipping = $deliveryfees;
        $insert_order->tax = $tax_amt;
        $insert_order->coupon_disc = $coupon_discount_amount;
        $insert_order->order_total = $total_amt;
        $insert_order->payment_type = $payment_type;
        $insert_order->payment_method = $payment_method;
        $insert_order->payment_status = $payment_status;
        $insert_order->ccinfo = $ccinfo;
        $insert_order->transaction_info = $tranid . '~' . $paypal_capture_id;
        $insert_order->payment_gateway_response = '';
        $insert_order->order_remark = $order_remark;
        $insert_order->checkout_type = $checkout_type;
        $insert_order->status = $status;
        $insert_order->ship_first_name = $first_name;
        $insert_order->ship_last_name = $last_name;
        $insert_order->ship_email = $email;
        $insert_order->ship_address1 = $address1;
        $insert_order->ship_address2 = !empty($address2) ? $address2 : '';
        $insert_order->ship_city = $city;
        $insert_order->ship_zip = $postalcode;
        $insert_order->ship_state = $state;
        $insert_order->ship_country = $country;
        $insert_order->ship_phone = $primaryphone;
        $insert_order->bill_first_name = $billing_first_name;
        $insert_order->bill_last_name = $billing_last_name;
        $insert_order->bill_email = $billing_email;
        $insert_order->bill_address1 = $billing_address1;
        $insert_order->bill_address2 = !empty($billing_address2) ? $billing_address2 : '';
        $insert_order->bill_city = $billing_city;
        $insert_order->bill_zip = $billing_postalcode;
        $insert_order->bill_state = $billing_state;
        $insert_order->bill_country = $billing_country;
        $insert_order->bill_phone = $billing_primaryphone;
        $insert_order->save();
        $order_id = $insert_order->id;

        //Taxcloud Tax calculations API
        if ($char_TAXSR == 'T') {
            $tc_param = array();
            $tc_param['apiLoginID'] = $TAX_apiLoginID;
            $tc_param['apiKey'] = $TAX_apiKey;
            $tc_param['customerID'] = $uid;
            $tc_param['cartID'] = $tc_cartID;
            $tc_param['orderID'] = $int_NNROD;
            $tc_param['dateAuthorized'] = $curDateTime;
            $tc_param['dateCaptured'] = $curDateTime;

            $tc_responses = fn_callTaxCloudApi("post", $tc_param, "AuthorizedWithCapture");

        }

        $status = "success";
        $msg = "Order placed";
        $type = '';

        $iteminfo = array();
        $item = count($prod_variant_ary);
		$param = array();
        $param['uid'] = $uid;
        $responses = callApi("post", $param, "getCartTotalItem");
		$cart = $responses['data'];
       
		$param = array();
        $param['uid'] = $uid;
        $responses = callApi("post", $param, "getCartTotalItem");
		$cart = $responses['data'];
		
        foreach ($prod_variant_ary as $key => $variant_id) {
            $quantity = $quantityAry[$key];

            $prodData = Product_variants::from('product_variants as pv')
                ->join('product as p', 'p.product_id', '=', 'pv.product_id')
                ->select('pv.product_id', 'pv.sale_price', 'p.seller_id', 'pv.variant_sku', 'p.product_name', 'pv.variant_barcode', 'p.is_section_zero', 'pv.current_stock')
                ->where('pv.variant_id', '=', $variant_id)
                ->first();
            $product_id = $prodData->product_id;
            $sale_price = $prodData->sale_price;
            $seller_id = $prodData->seller_id;
            $variant_sku = $prodData->variant_sku;
            $product_name = $prodData->product_name;
            $variant_barcode = $prodData->variant_barcode;
            $is_section_zero = $prodData->is_section_zero;
            $current_stock = $prodData->current_stock;
            $updated_stock = $current_stock - $quantity;

            if ($is_section_zero == '1') {
                //update product stock
                Product_variants::where('variant_id', '=', $variant_id)->update(['current_stock' => $updated_stock]);
            }

            $product_price = $sale_price * $quantity;
            $iteminfo[$variant_id]['item_name'] = $product_name;
            $iteminfo[$variant_id]['qty'] = $quantity;
			$iteminfo[$variant_id]['sale_price'] = $sale_price;
			$iteminfo[$variant_id]['total_price'] = $product_price;
			
			$getproductinfo = explode('<>',getProductImgWithAttributeInfo($variant_id,$cart));
			$iteminfo[$variant_id]['product_image'] = $getproductinfo[0];
			$iteminfo[$variant_id]['attinfo'] = $getproductinfo[1];
			
			$seller_iteminfo[$seller_id]['iteminfo'][$variant_id]['item_name'] = $product_name;
			$seller_iteminfo[$seller_id]['iteminfo'][$variant_id]['qty'] = $quantity;
			$seller_iteminfo[$seller_id]['iteminfo'][$variant_id]['sale_price'] = $sale_price;
			$seller_iteminfo[$seller_id]['iteminfo'][$variant_id]['total_price'] = $product_price;
			$seller_iteminfo[$seller_id]['iteminfo'][$variant_id]['product_image'] = $getproductinfo[0];
			$seller_iteminfo[$seller_id]['iteminfo'][$variant_id]['attinfo'] = $getproductinfo[1];
			
			if(!isset($seller_iteminfo[$seller_id]['seller_subtotal']))
			$seller_iteminfo[$seller_id]['seller_subtotal'] = 0;	
			$seller_iteminfo[$seller_id]['seller_subtotal'] += $product_price;

            $prod_proportion = round(($product_price / $total_prod_amt), 2);

            $prod_tax = 0;
            if ($char_TAXSR == 'T') {
                $prod_tax = $lookup_taxamount_array[$variant_id];
            } else {
                $prod_tax = round($tax_amt * $prod_proportion, 2);
            }
			
			$seller_iteminfo[$seller_id][$variant_id]['prod_tax'] = $prod_tax;
			if(!isset($seller_iteminfo[$seller_id]['seller_tax']))
			$seller_iteminfo[$seller_id]['seller_tax'] = 0;
			$seller_iteminfo[$seller_id]['seller_tax'] += $prod_tax;
			
			if(!isset($seller_iteminfo[$seller_id]['seller_total']))
			$seller_iteminfo[$seller_id]['seller_total'] = 0;
			$seller_iteminfo[$seller_id]['seller_total'] += $product_price + $prod_tax;	

            $coupon_amt = round($coupon_discount_amount * $prod_proportion, 2);

            $binshelf_id = $seller_comm = $inventorylink_id = $from_inv_depot_addr_id = $inventory_id = $inv_entity_id = $inv_qty = $depot_entity_id = 0;
            $inv_data = Inventory::from('inventory as i')
                ->join('entity as e', 'i.entity_id', '=', 'e.entity_id')
                ->join('binshelf as bs', 'i.binshelf_id', '=', 'bs.binshelf_id')
                ->join('inventorylink as il', 'bs.inventorylink_id', '=', 'il.inventorylink_id')
                ->select('e.seller_comm', 'e.primary_address_id', 'i.binshelf_id', 'bs.inventorylink_id', 'i.inventory_id', 'i.entity_id as inv_entity_id', 'i.quantity as inv_qty', 'il.depot_entity_id')
                ->where('i.products_variants_id', '=', $variant_id)
                ->where('i.seller_id', '=', $seller_id)
                ->where(function ($q) use ($curDate) {
                    $q->where('e.endeffdt')
                        ->orwhere('e.endeffdt', '=', '0000-00-00')
                        ->orwhere('e.endeffdt', '>', $curDate);
                })
                ->first();
            if (!is_null($inv_data)) {
                $seller_comm = $inv_data->seller_comm;
                $from_inv_depot_addr_id = $inv_data->primary_address_id;
                $binshelf_id = $inv_data->binshelf_id;
                $inventorylink_id = $inv_data->inventorylink_id;
                $inventory_id = $inv_data->inventory_id;
                $inv_entity_id = $inv_data->inv_entity_id;
                $inv_qty = $inv_data->inv_qty;
                $depot_entity_id = $inv_data->depot_entity_id;
            }
            $seller_comm_amount = round(($product_price * ($seller_comm / 100)), 2);
            $teak_amount = round(($product_price * $realvar_TEAKP), 2);

            $int_NNBCD = System::getNxtSystemintvar('NNBCD');
            $routehops_id = 0;
            if ($inv_entity_id == $seller_id) {
                $sr_data = Standardroute::select('route_id')
                    ->where('seller_id', '=', $seller_id)
                    ->where(function ($q) use ($curDate) {
                        $q->where('endeffdt')
                            ->orwhere('endeffdt', '=', '0000-00-00')
                            ->orwhere('endeffdt', '>', $curDate);
                    })
                    ->first();
                $pickuproute_id = 0;
                if (!is_null($sr_data)) {
                    $pickuproute_id = $sr_data->route_id;
                }

                $rh_data = Routehops::select('routehops_id')
                    ->where('type', '=', 'R')
                    ->where('pickuproute_id', '=', $pickuproute_id)
                    ->where('deliveryroute_id', '=', $deliveryroute_id)
                    ->first();
                if (!is_null($rh_data)) {
                    $routehops_id = $rh_data->routehops_id;
                }
            } else {

                $rh_data = Routehops::select('routehops_id')
                    ->where('type', '=', 'I')
                    ->where('from_inv_depot_addr_id', '=', $from_inv_depot_addr_id)
                    ->where('deliveryroute_id', '=', $deliveryroute_id)
                    ->first();
                if (!is_null($rh_data)) {
                    $routehops_id = $rh_data->routehops_id;
                }
            }

            //INSERT ec_orderdetai
            $insert_orderdetail = new Orderdetail;
            $insert_orderdetail->order_id = $order_id;
            $insert_orderdetail->order_no = $int_NNROD;
            $insert_orderdetail->seller_id = $seller_id;
            $insert_orderdetail->product_id = $product_id;
            $insert_orderdetail->product_sku = $variant_sku;
            $insert_orderdetail->product_name = $product_name;
            $insert_orderdetail->product_variant = $variant_id;
            $insert_orderdetail->product_barcode = $variant_barcode;
            $insert_orderdetail->order_detail_barcode = $int_NNBCD;
            $insert_orderdetail->product_price = $sale_price;
            $insert_orderdetail->quantity = $quantity;
            $insert_orderdetail->total_price = $product_price;
            $insert_orderdetail->tax = $prod_tax;
            $insert_orderdetail->coupon = $coupon_amt;
            $insert_orderdetail->seller_comm_amount = $seller_comm_amount;
            $insert_orderdetail->shipping_method = $shipping_method;
            $insert_orderdetail->status = 'Pending';
            $insert_orderdetail->route_hops_id = $routehops_id;
            $insert_orderdetail->save();
            $order_detail_id = $insert_orderdetail->id;

            if ($routehops_id > 0) {
                //Get seller_address_id of seller_id
                $seller_Data = Entity::from('entity as e')
                    ->join('entityaddress as ea', function ($join) {
                        $join->on('e.entity_id', '=', 'ea.entity_id')
                            ->whereRaw('ec_e.primary_address_id != ec_ea.entity_address_id');
                    })
                    ->select('ea.entity_address_id')
                    ->where('e.entity_id', '=', $seller_id)
                    ->where(function ($q) use ($curDate) {
                        $q->where('ea.endeffdt')
                            ->orwhere('ea.endeffdt', '=', '0000-00-00')
                            ->orwhere('ea.endeffdt', '>', $curDate);
                    })
                    ->first();
                if (!is_null($seller_Data)) {
                    $seller_entityaddr_id = $seller_Data->entity_address_id;
                } else {
                    $seller_entityaddr_id = 0;
                }

                $rhd_data = Routehopsdetail::select('route_id', 'sequencenumber')
                    ->where('routehops_id', '=', $routehops_id)
                    ->get();
                foreach ($rhd_data as $key => $value) {
                    $route_id = $value->route_id;
                    $sequencenumber = $value->sequencenumber;

                    //INSERT ec_stagingroute
                    $insert_sr = new Stagingroute;
                    $insert_sr->type = 'D';
                    $insert_sr->route_id = $route_id;
                    $insert_sr->order_detail_id = $order_detail_id;
                    $insert_sr->seller_entityaddr_id = $seller_entityaddr_id;
                    $insert_sr->customer_entityaddr_id = $address_id;
                    $insert_sr->sequence = $sequencenumber;
                    $insert_sr->status = 'E';
                    $insert_sr->save();
                }
            } //END if ($routehops_id > 0)

            //Insert into ec_inventoryxtn
            $_status = '';
            if ($is_section_zero == '0') {
                $_status = 'B';
            } else {
                $_status = 'P';
            }
            $ins_invxtn = new Inventoryxtn;
            $ins_invxtn->inventorylink_id = $inventorylink_id;
            $ins_invxtn->products_variants_id = $variant_id;
            $ins_invxtn->order_detail_id = $order_detail_id;
            $ins_invxtn->seller_entity_id = $seller_id;
            $ins_invxtn->quantity = $quantity;
            $ins_invxtn->inout = 'O';
            $ins_invxtn->status = $_status;
            $ins_invxtn->binshelf_id = $binshelf_id;
            $ins_invxtn->inventory_id = $inventory_id;
            $ins_invxtn->postedflag = 'N';
            $ins_invxtn->save();
            $new_invxtn_id = $ins_invxtn->inventoryxtn_id;

            $product_cost_amount = round(($product_price - $seller_comm_amount), 2);
            $ins_fxc = new Financialxtnctl;
            $ins_fxc->xtn_date = $curDateTime;
            $ins_fxc->order_id = $order_id;
            $ins_fxc->order_detail_id = $order_detail_id;
            $ins_fxc->seller_id = $seller_id;
            $ins_fxc->customer_id = $entity_id;
            $ins_fxc->product_id = $product_id;
            $ins_fxc->quantity = $quantity;
            $ins_fxc->tax_rates_id = $tax_rates_id;
            $ins_fxc->xtn_type = 'O';
            $ins_fxc->product_cost_amount = $product_cost_amount;
            $ins_fxc->seller_payment_status = 'P';
            $ins_fxc->tax_amount = $prod_tax;
            $ins_fxc->tax_payment_status = 'P';
            $ins_fxc->product_sale_amount = $product_price;
            $ins_fxc->delivery_amount = '';
            $ins_fxc->teak_amount = $teak_amount;
            $ins_fxc->teak_payment_status = 'P';
            $ins_fxc->save();

            //Task#9214 Starts
            if ($inv_entity_id != $seller_id && $char_NOHND =='Y') {
                $final_qty = $inv_qty - $quantity;
                if($final_qty > 0) {
                    Inventory::where('inventory_id', '=', $inventory_id)->update(['quantity' => $final_qty]);
                } else {
                    Inventory::where('inventory_id', '=', $inventory_id)->update(['quantity' => $final_qty, 'endeffdt' => $curDate]);
                }

                Inventoryxtn::where('inventoryxtn_id', '=', $new_invxtn_id)->update(['users_id' => $uid, 'postedflag' => 'Y', 'status' => 'C']);

                
                $staging_data = Stagingroute::select('stagingroute_id')
                    ->where('order_detail_id', '=', $order_detail_id)
                    ->orderBy('sequence', 'ASC')->first();
                $stagingroute_id = 0;
                if (isset($staging_data)) {
                    $stagingroute_id = $staging_data->stagingroute_id;
                }
                if($stagingroute_id > 0) {
                    Stagingroute::where('stagingroute_id', '=', $stagingroute_id)->update(['status' => 'I']);
                }

                $ins_floor = new Floor;
                $ins_floor->entity_id = $depot_entity_id;
                $ins_floor->order_detail_id = $order_detail_id;
                $ins_floor->status = 'O';
                $ins_floor->inventory_xtn_id = $new_invxtn_id;
                $ins_floor->reccreatedt = $curDate;
                $ins_floor->save();

            }//END if ($inv_entity_id != $seller_id && $char_NOHND =='Y')
            //Task#9214 Ends

        }

        if ($deliveryfees > 0) {
            $ins_fxc = new Financialxtnctl;
            $ins_fxc->xtn_date = $curDateTime;
            $ins_fxc->order_id = $order_id;
            $ins_fxc->customer_id = $entity_id;
            $ins_fxc->xtn_type = 'S';
            $ins_fxc->delivery_amount = $deliveryfees;
            if ($char_TAXSR == 'T') {
                $ins_fxc->tax_amount = $lookup_taxamount_array[0];
            }
            $ins_fxc->save();
        } //END if ($deliveryfees > 0)

        DB::table("cart")->where('user_id', $uid)->delete();
        $success = 'success';
        $msg = 'Order placed Successfully';
		
		$infoarray = array();
		$infoarray['first_name'] = $first_name;
		$infoarray['last_name'] = $last_name;
		$infoarray['address1'] = $address1;
		$infoarray['city'] = $city;
		$infoarray['state'] = $state;
		$infoarray['postalcode'] = $postalcode;
		$infoarray['primaryphone'] = $primaryphone;
		$infoarray['total_prod_amt'] = $total_prod_amt;
		$infoarray['deliveryfees'] = $deliveryfees;
		$infoarray['tax_amt'] = $tax_amt;
		$infoarray['total_amt'] = $total_amt;
												
	    sendmail_sendgrid($iteminfo,$seller_iteminfo,$email,$infoarray,$int_NNROD);
        							
        $msg = "Order placed Successfully";
        $response = array();
        $response["status"] = 'success';
        $response["msg"] = $msg;
        $response["type"] = '';
        $response["ORDER_ID"] = $order_id;
        $response["ORDER_NO"] = $int_NNROD;
        return response()->json([
            "success" => "1",
            "status" => "200",
            "message" => $msg,
            "data" => $response,
        ], 200);

    }
	
	

}
function sendmail_sendgrid($iteminfo,$seller_iteminfo,$email,$infoarray,$int_NNROD)
{
					
	$val_SGRID = System::getSystemval('SGRID', 'strvar');
	$val_SGRID_ARR = explode("~", $val_SGRID);
	$default_from_email = $val_SGRID_ARR[1];

	$LogoList = get_homepage_section_content("LOGO");
	$logo_path = "";
	foreach ($LogoList as $LogoItem) {
	$logo_path = $LogoItem['image'];
	$IMG_URL = env('IMG_URL');
	$logo_path = $IMG_URL.$logo_path;
	}
	
	$email_temp = DB::table("email_templates")->where('title', 'Customer Order Confirmation')->where('status', '1')->select('title', 'subject','template_var_name', 'mail_body','from_email')->first();
								
								if (!is_null($email_temp)) {
									$title = $email_temp->title;
									$template_id = $email_temp->template_var_name;
									$from_email = $email_temp->from_email;
									if($from_email == '')
								    $from_email = $default_from_email;
								
									$subject = $email_temp->subject;
									
									$cust_name= $infoarray['first_name']." ".$infoarray['last_name'];	
									$CURLOPT_POSTFIELDS = '{
									"from":{
										  "email":"'.$from_email.'"
									   },
									   "personalizations":[
										  {
											 "to":[
												{
												   "email":"'.$email.'"
												}
											 ],
											 "dynamic_template_data":{
												"logo":"'.$logo_path.'",
												"subject": "'.$subject.'",
												"order_no":"'.$int_NNROD.'",
												"name":"'.$cust_name.'",
												"shipping_name":"'.$infoarray['first_name'].'",
												"shipping_address":"'.$infoarray['address1'].'",
												"shipping_city":"'.$infoarray['city'].'",
												"shipping_state":"'.$infoarray['state'].'",
												"shipping_zipcode":"'.$infoarray['postalcode'].'",
												"shipping_phone":"'.$infoarray['primaryphone'].'",
												"subtotal":"'.
												number_format($infoarray['total_prod_amt'], 2, '.', '').'",
												"shipping":"'.number_format($infoarray['deliveryfees'], 2, '.', '').'",
												"tax":"'.number_format($infoarray['tax_amt'], 2, '.', '').'",
												"total":"'.number_format($infoarray['total_amt'], 2, '.', '').'",';
												
									$val_EMAIL = System::getSystemval('EMAIL', 'strvar');	
									$val_PHONE = System::getSystemval('PHONE', 'strvar');
									list($phone, $timing) = explode('~', $val_PHONE);
									$contact_no = $phone;
								
									$CURLOPT_POSTFIELDS .=  ' "contact_no":"'.$contact_no.'",
									"contact_email":"'.$val_EMAIL.'",';			
									$CURLOPT_POSTFIELDS .= '
										 "items":[ ';
												
									$pcnt= 0;
									foreach($iteminfo as $key=>$productinfo)
									{
										if($pcnt == 0)
										$CURLOPT_POSTFIELDS .=  '{';
										else
										{
											$CURLOPT_POSTFIELDS .=  ',
											{';
										}
										$CURLOPT_POSTFIELDS .=  ' "name":"'.$productinfo['item_name'].'",
										  "image":"'.$productinfo['product_image'].'",
										  "price":"'.number_format($productinfo['sale_price'], 2, '.', '').'",
										  "qty":"'.$productinfo['qty'].'",
										  "total":"'.number_format($productinfo['total_price'], 2, '.', '').'"';
										  if($productinfo['attinfo'] != '')
										  {
											  $CURLOPT_POSTFIELDS .= '
											  ,"attributes":[ ';
											  $attinfoarr = explode('!~!',$productinfo['attinfo']);
											  $acnt= 0;
											  foreach($attinfoarr as $attinfo)
											  {
												  
												$att = explode(':',$attinfo);
												if($acnt == 0)
												$CURLOPT_POSTFIELDS .=  '{';
												else
												{
													$CURLOPT_POSTFIELDS .=  ',
													{';
												}
												$CURLOPT_POSTFIELDS .=  '"att_name":"'.$att[0].'",
												"att_val":"'.addslashes($att[1]).'"';
												$CURLOPT_POSTFIELDS .=  '}';
												$acnt++;
											  }
											  $CURLOPT_POSTFIELDS .= ']';
														
										  }
										 
										  $CURLOPT_POSTFIELDS .=  '}';
										  $pcnt++;
									}
												
										
										
												  
									$CURLOPT_POSTFIELDS .=			'
												]
												
											 }
										  }
									   ],
									   "template_id":"'.$template_id.'"
									}';
									
									$param = array();
									$param['CURLOPT_POSTFIELDS'] = $CURLOPT_POSTFIELDS;
									$responses = callApi("post", $param, "sendGridMail");
									
								}
								
								$email_temp = DB::table("email_templates")->where('title', 'Seller Order Confirmation')->where('status', '1')->select('title', 'subject','template_var_name', 'mail_body','from_email')->first();
								
								if (!is_null($email_temp)) {
									$title = $email_temp->title;
									$template_id = $email_temp->template_var_name;
									$from_email = $email_temp->from_email;
									if($from_email == '')
								    $from_email = $default_from_email;
									$subject = $email_temp->subject;
									$cust_name= $infoarray['first_name']." ".$infoarray['last_name'];
									
									
									//prx($logo_path);
									$productinfo = array();
									$seller_items = array();
									foreach($seller_iteminfo as $selRetailerId => $seller_items){
										$seller_subtotal = $seller_items['seller_subtotal'];
										$seller_tax = $seller_items['seller_tax'];
										$seller_total = $seller_items['seller_total'];
										
										$EntityData = Entity::join('entityaddress as ea_store',function($join){
											$join->on('ea_store.entity_address_id', '!=', 'entity.primary_address_id')
											 ->on('ea_store.entity_id', '=', 'entity.entity_id');
										})
										->select('entity.name as seller_name','ea_store.email_address as store_email')
										->where('entity.entity_id', '=', $selRetailerId)
										->whereNotNull('ea_store.email_address')
										->get();
											
										foreach($EntityData as $data)
										{
											$seller_name = $data->seller_name;
											$store_email = $data->store_email;
										}
										
										$CURLOPT_POSTFIELDS1 = '{
										"from":{
											  "email":"'.$from_email.'"
										   },
										   "personalizations":[
											  {
												 "to":[
													{
													   "email":"'.$store_email.'"
													}
												 ],
												 "dynamic_template_data":{
													"logo":"'.$logo_path.'",
													"subject": "'.$subject.'",
													"order_no":"'.$int_NNROD.'",
													"name":"'.$seller_name.'",
													"shipping_name":"'.$infoarray['first_name'].'",
													"shipping_address":"'.$infoarray['address1'].'",
													"shipping_city":"'.$infoarray['city'].'",
													"shipping_state":"'.$infoarray['state'].'",
													"shipping_zipcode":"'.$infoarray['postalcode'].'",
													"shipping_phone":"'.$infoarray['primaryphone'].'",
													"subtotal":"'.number_format($seller_subtotal, 2, '.', '').'",
													"tax":"'.number_format($seller_tax, 2, '.', '').'",
													"total":"'.number_format($seller_total, 2, '.', '').'",';
													
										$val_EMAIL = System::getSystemval('EMAIL', 'strvar');	
										$val_PHONE = System::getSystemval('PHONE', 'strvar');
										list($phone, $timing) = explode('~', $val_PHONE);
										$contact_no = $phone;
									
										$CURLOPT_POSTFIELDS1 .=  ' "contact_no":"'.$contact_no.'",
										"contact_email":"'.$val_EMAIL.'",';			
										$CURLOPT_POSTFIELDS1 .= '
											 "items":[ ';
													
										$pcnt= 0;
										
										foreach($seller_items['iteminfo'] as $key=>$productinfo)
										{
											if($pcnt == 0)
											$CURLOPT_POSTFIELDS1 .=  '{';
											else
											{
												$CURLOPT_POSTFIELDS1 .=  ',
												{';
											}
											
											$CURLOPT_POSTFIELDS1 .=  ' "item_name":"'.$productinfo['item_name'].'",
											  "image":"'.$productinfo['product_image'].'",
											  "price":"'.number_format($productinfo['sale_price'], 2, '.', '').'",
											  "qty":"'.$productinfo['qty'].'",
											  "total":"'.number_format($productinfo['total_price'], 2, '.', '').'"';
											  if($productinfo['attinfo'] != '')
											  {
												  $CURLOPT_POSTFIELDS1 .= '
												  ,"attributes":[ ';
												  $attinfoarr = explode('!~!',$productinfo['attinfo']);
												  $acnt= 0;
												  foreach($attinfoarr as $attinfo)
												  {
													  
													$att = explode(':',$attinfo);
													if($acnt == 0)
													$CURLOPT_POSTFIELDS1 .=  '{';
													else
													{
														$CURLOPT_POSTFIELDS1 .=  ',
														{';
													}
													$CURLOPT_POSTFIELDS1 .=  '"att_name":"'.$att[0].'",
													"att_val":"'.addslashes($att[1]).'"';
													$CURLOPT_POSTFIELDS1 .=  '}';
													$acnt++;
												  }
												  $CURLOPT_POSTFIELDS1 .= ']';
															
											  }
											 
											  $CURLOPT_POSTFIELDS1 .=  '}';
											  $pcnt++;
										}
													
											
											
													  
										$CURLOPT_POSTFIELDS1 .=			'
													]
													
												 }
											  }
										   ],
										   "template_id":"'.$template_id.'"
										}';
										
										$param = array();
										$param['CURLOPT_POSTFIELDS'] = $CURLOPT_POSTFIELDS1;
										$responses = callApi("post", $param, "sendGridMail");
										
									}
								}
}
function getProductImgWithAttributeInfo($id, $cart) {
    foreach ($cart as $key => $val) {
       if ($val['variant_id'] == $id) {
           $product_image = $cart[$key]['product_image'];
		   $attinfo = $cart[$key]['attinfo'];
		  
		   //WE GET $product_image With folder path So we required image name for encoding url only image name
		   $lastIndex = strripos($product_image,'/')+1;
		   $product_image_folder = substr($product_image, 0, $lastIndex);
		   $product_image_name = rawurlencode(substr($product_image, $lastIndex));
		   
		   $IMG_URL = env('IMG_URL');
		   //prx($IMG_URL.$product_image_folder.$product_image_name."?".$attinfo);
		   return $IMG_URL.$product_image_folder.$product_image_name."<>".$attinfo;
       }
    }
    return "<>";
}
function GetCarrierInfo() {
	$public_path = public_path();
	$FileName = $public_path."/carrierinfo.txt";
    // READ THE FILE IN ARRAY
    $FileArray = file($FileName);
    $ReturnArray = array();
	for ($CntFL = 0; $CntFL < count($FileArray); $CntFL++) {
        $carrierInfoArr =  explode(",",$FileArray[$CntFL]);
		$carrier_name = trim($carrierInfoArr[0]);
		$carrier_service_code = trim($carrierInfoArr[1]);
		$carrier_package = trim($carrierInfoArr[2]);
		$carrier_service_type = trim($carrierInfoArr[3]);
		//$ReturnArray[$carrier_name][$carrier_package]['service_code'] =  $carrier_service_code;
		$ReturnArray[$carrier_name][$carrier_service_code.'~'.$carrier_package]['carrier_service_type'] =  $carrier_service_type;
		
        
    }
    return $ReturnArray;
   }
function searchArray($key, $st, $array) {
   foreach ($array as $k => $v) {
       if ($v[$key] === $st) {
           return $k;
       }
   }
   return null;
}
