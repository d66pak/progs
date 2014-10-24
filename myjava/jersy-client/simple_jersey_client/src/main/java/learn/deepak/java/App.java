package learn.deepak.java;

import javax.ws.rs.core.MediaType;
import com.sun.jersey.api.client.Client;
import com.sun.jersey.api.client.ClientResponse;
import com.sun.jersey.api.client.WebResource;

import yjava.ycore.yax.YAX;
import yjava.ycore.yax.YAXProvider;
import yjava.ycore.yax.YAXException;

/**
 * Hello world!
 * 
 */
public class App {

    private static String mArgs = new String(
                                        "acct=acctVal&user=yqa_test_user@abc.com&intl=us&bd=1980,9,6&.src=srcval&action=register,migrate");
    private static String mArgs1 = new String(
                                        "acct=acctVal&intl=us&bd=1980,9,6&.src=srcval&action=register,migrate");

    public static void main(String[] args) {
        System.out.println("Hello REST Jersey Client!");

        YAX yax = YAXProvider.createYax();
        String encodedArgs = null;
        String encodedArgs1 = null;
        try {

            encodedArgs = yax.encryptRocketmailData(mArgs);
            encodedArgs1 = yax.encryptRocketmailData(mArgs1);
        } catch (YAXException ye) {
            System.out.println("yax encription failed : " + ye.getMessage());
        }

        if (encodedArgs != null) {

            System.out.println("Encoded args: " + encodedArgs);
        }
        if (encodedArgs1 != null) {

            System.out.println("Encoded args 1: " + encodedArgs1);
        }

        String decodedQueryString = null;
        String ds1 = null;
        String ds2 = null;
        try {

            decodedQueryString = yax.decryptRocketmailData("IXJ0YnVKIWZkZHNKIWFmdXpKIXR7YmNKNyF0c2ZzcnRKYnV1eHUhdGRK");
            ds1 = yax.decryptRocketmailData("IXJ0YnVKUlRCVV5DaFJZXFlYUFkhZmRkc0ohYWZ1ekohdHtiY0ohdHNmc3J0SmJ1dXh1IXRkSlp%2bdHR%2beWAnIH4gJ3dmdWZ6");
            ds2 = yax.decryptRocketmailData("IXJ0YnVKUlRCVV5DaFJZXFlYUFkhZmRkc0ohYWZ1ekohdHtiY0ohdHNmc3J0SmJ1dXh1IXRkSg%3d%3d");
        } catch (YAXException ye) {

            System.out.println("Decription failed : " + ye.getMessage());
        }

        if (decodedQueryString != null) {

            System.out.println("Decoded iParam : " + decodedQueryString);
        }
        if (ds1 != null) {
            
            System.out.println("ds1 : " + ds1);
        }
        if (ds2 != null) {
            
            System.out.println("ds2 : " + ds2);
        }
        Client client = Client.create();
        WebResource webResource = client.resource(
                "http://cluethrough.corp.gq1.yahoo.com:4080/rg/AccessMailRegister").queryParam("i",
                encodedArgs).queryParam("j", "xyz");
        System.out.println("Request : " + webResource.toString());
        ClientResponse response = webResource.accept(MediaType.TEXT_HTML).get(
                ClientResponse.class);
        
        System.out.println("Status  : " + response.getStatus());
        System.out.println("Response: " + response.getEntity(String.class));
    }
}
