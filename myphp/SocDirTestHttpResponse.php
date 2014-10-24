<?php
/**
 * @author Viral Sangani - virals
 */

require('PSWAT/Tests/YOS/SocialDirectory/SocDirTest/src/SocDirTestResponseDecoder.php');


class SocDirTestHttpResponse{

	public $objResponse_;

	public function __construct($response) {
		$this->parse($response);
	}

	/*
	 ** Returns true if expression evaluates to true
	 */
	public function evaluate($expression) {
			$respValue = $expression;
			$ind = strpos($respValue, " ==");
			$respValue = substr($respValue, 0, $ind);
			$respValue1 = "\$this->objResponse_->$respValue";
			$respValue1 = "\$ret1 = ($respValue1);";
			eval($respValue1);

			if(((ereg("false",$expression) == 1) || (ereg("true",$expression) ==1 ))  && (!is_bool($ret1))) {
				
				$rval = $expression;
				$ind = strpos($rval, " ==");
				$rval = substr($rval,$ind+4);


				if($ret1 == $rval) {
					return true;	
				}
				else {
					return false;
				}

			}
			else {
				$expr = "\$ret = (\$this->objResponse_->$expression);";
				eval($expr);
				return ($ret);

			}
	}
	
	public function checkUrlMask($expression) {
		$ret = 0;
		$expressionArray = explode(" urlMask ", $expression);
		$exprA  = explode("=", $expressionArray[1]);
		$expr = "\$ret0 = (\$this->objResponse_->$expressionArray[0]);";
		eval($expr);
		if(eregi($expressionArray[1], $ret0) == 1){
			$ret = 1;
		}

		return ($ret);
	}

	public function checkSubString ($expression ) {
		$ret = 0;
		if ( eregi ( "substring" ,  $expression ) ) {
			$expressionArray = explode(" subString ", $expression);
			$match =  true ; 
		}
		else {
			$expressionArray = explode ( " subNoStringMatch " , $expression ) ;
			$match = false ; 
		}
		$exprA  = explode("=", $expressionArray[1]);
		$expr = "\$ret0 = (\$this->objResponse_->$expressionArray[0]);";
		eval($expr);
		$matchString = '/'.$expressionArray[1] . '/' ; 
		if( (preg_match ($matchString , $ret0) &&  $match== true ) ||  (preg_match ( $matchString , $ret0 )==0   && $match==false )){

			$ret = 1;
		}
		return ($ret);
	}


	 public function checkKeyexists  ($expression ) {
                $ret = 0;
		if ( eregi ( "keyexists" ,  $expression ) ) {
			$expressionArray = explode(" keyexists ", $expression);
			$exists  =  true ; 
		}
		else {
			$expressionArray = explode ( " keydoesnotexists " , $expression ) ;
			$exists  = false ; 
		}
                $expr = "\$ret0 = (\$this->objResponse_->$expressionArray[0]->$expressionArray[1]);";
                eval($expr);
                if ( (isset( $ret0 )  && $exists ==true ) || ( isset ($ret0) == 0 && $exists ==false ) )
                        $ret =1 ;
                return ($ret);
        }

	//THis function will check if any value is set for the  given string 
	public function checkValueSet ( $expression   ) {
	
                $ret = 0;
		if ( eregi ( "valueset" ,  $expression ) ) {
			$expressionArray = explode(" valueset ", $expression);
			$set  =  true ; 
		}
		else {
			$expressionArray = explode ( " valuenotset " , $expression ) ;
			$set  = false ; 
		}
                $expr = "\$ret0 = (\$this->objResponse_->$expressionArray[0]->$expressionArray[1]);";
                eval($expr);
                if ( ($ret0!= ""   && $set==true ) || ( $ret0=="" && $set==false ))
                        $ret =1 ;
                return ($ret);
        }

/*
	 ** Returns true if expression evaluates to true for a contains condition
	 */
	public function evaluateContains($expression) {
		$expressionArray = explode(" contains ", $expression);
		$exprA  = explode("=", $expressionArray[1]);
		$expr = "\$ret0 = (\$this->objResponse_->$expressionArray[0]);";
		eval($expr);
		if(is_array($ret0)) {
			foreach ($ret0 as $val) {
				var_dump($val);
				if($val->$exprA[0]==$exprA[1]){
					return true;
				}
			}

		}
		if( in_array ( $exprA[1] ,  $ret0)  )
		{
				return true;
		}
		return false;
	}



	public function evaluateContainsArray($expression) {
		$expressionArray = explode(" containsArray ", $expression);
		$data_str = $expressionArray[1];
		$data_str = trim($data_str,"array\( ");
		$data_str = trim($data_str," \)\"");
		$data_str = ereg_replace(" *\" *","",$data_str);


		$arr = explode(",",$data_str);


  
		$arrResp = array();
		for( $i=0; $i<count($arr); $i++) {
			$tempArr = explode("=>",$arr[$i]);
			$arrResp[$tempArr[0]] = $tempArr[1];

		}
		var_dump($arrResp);

		$expr = "\$ret0 = (\$this->objResponse_->$expressionArray[0]);";
		eval($expr);
		print_r($ret0);
	
		if(is_array($ret0)){	
			for( $i=0; $i<count($ret0); $i++) {
				$arr1 = (array)$ret0[$i];

				if($arr1 == $arrResp) {
					var_dump("Yo the ARRAY IS FOUND  for .\n");
					print_r($arr1);
					return true;
				}
			}
		}
		return false;
	}

		/*
	 ** Returns true if expression evaluates to true
	 */
	public function getBodyString($response) {
		$nHeader = strpos($response, "\r\n\r\n");
		$header = substr($response, 0, $nHeader);
		$body = substr($response, $nHeader+4);
		return ($body);
	}


	public function parse($response) {

		println("*******Parse>>response is ");

		$nHeader = strpos($response, "\r\n\r\n");
		$header = substr($response, 0, $nHeader);
		$body = substr($response, $nHeader+4);

		$this->parseHttpResponseHeader($header);
		$this->parseHttpResponseBody($body);

	}


	protected function array_to_obj($array, &$obj) {
		foreach ($array as $key => $value) {
			if (is_array($value)) {
				$obj->$key = new stdClass();
				$this->array_to_obj($value, $obj->$key);
			} else {
				$obj->$key = $value;
			}
		}
		return $obj;
	}


	public function parseHttpResponseHeader($header) {
		$arrResponseLines = split("[\n\r]+", $header);

		// First line of headers is the HTTP response code
		$http_response_line = array_shift($arrResponseLines);
		if(preg_match('@^HTTP/[0-9]\.[0-9] ([0-9]+) (.*)@',$http_response_line, $matches)) {
			$response_code = $matches[1];
			$response_reason = $matches[2];
		}

		$response_header_array['code'] = $response_code;
		$response_header_array['reason'] = $response_reason;

		// put the rest of the headers in an array
		$arrRespHeaders = array();
		for( $i=0; $i<count($arrResponseLines); $i++) {
			$header_line = $arrResponseLines[$i];
			list($header,$value) = explode(': ', $header_line, 2);
			$response_header_array[$header] = $value;
		}


		$arrResponse =  array(
                        "header" => $response_header_array,
                        "body" => null
		);

		$this->objResponse_ = new stdClass();
		$this->array_to_obj($arrResponse, $this->objResponse_);

	}

	public function parseHttpResponseBody($body) {
		$content_type = $this->objResponse_->header->{"Content-Type"};

		if (strstr($content_type, "/xml")) {
			// XML Decode
			$objXmlDec = new SocDirTestResponseDecoder($body);
			$this->objResponse_->body = $objXmlDec->XMLDecoder_data;
		} elseif (strstr($content_type, "/json")) {
			// JSON decode
			$this->objResponse_->body = json_decode($body);
				
		}
		else {
			// Something else in content-type, could be text/plain
			// Include it as it is.
			$this->objResponse_->body = json_decode($body);
		}

	}
/*
	public function getHeader(){
		return $this->header;
	}

	public function getBody(){
		return $this->objResponse_->body;
	}

	public function getHeaderCode(){
		return $this->response_code;
	}

	public function getHeaderReason(){
		return $this->response_reason;
	}

	public function getHeaderArray(){
		return $this->response_header_array;
	}

	public function getHeaderContentType(){
		return $this->content_type;
	}

	public function getBodyObject(){
		return $this->bodyObject;
	}
*/
}

?>
