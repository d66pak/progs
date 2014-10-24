/*
#include <iostream>
#include <curl/curl.h>

int main(void)
{
  CURL *curl;
  CURLcode res;

  curl = curl_easy_init();
  if (curl) {

    curl_easy_setopt(curl, CURLOPT_URL, "http://example.com");

    string post_data("some json data");
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, post_data.c_str());

    res = curl_easy_perform(curl);

    if (res != CURL_OK) {

      cout << "curl_easy_perform failed: " << curl_easy_strerror(res) << endl;
    }

    curl_easy_cleanup(curl);
  }
  else {

    cout << "curl_easy_init failed" << endl;
  }
  return 0;
}
*/
#include <iostream>
#include <string>
#include <sstream>
#include <curl/curl.h>
#include <yut/ostrstream.h>
#include <yca/yca.h>
#include <json/json.h>

/*
 * g++ -I/home/y/include -L/home/y/lib -lcurl -lyax -lyca -ljson_cpp -o curl-simple-post curl-simple-post.cpp
 */

static const yutString WS_URL("http://jws100.mail.vip.ne1.yahoo.com/ws/extacct/v1/account/id/");
static const yutString ACTIVATE_REQ("/activate");
static const yutString DEACTIVATE_REQ("/deactivate");
static const yutString EMAILID("alpo_test01@exlab.corp.gq1.yahoo.com");

int TraceFunction(CURL *, curl_infotype type, unsigned char *data, size_t size, void *)
{
  string text;

  switch (type)
  {
    case CURLINFO_TEXT:
      text = "== Info";
      break;
    case CURLINFO_HEADER_OUT:
      text = "=> Send header";
      break;
    case CURLINFO_DATA_OUT:
      text = "=> Send data";
      break;
    case CURLINFO_HEADER_IN:
      text = "<= Recv header";
      break;
    case CURLINFO_DATA_IN:
      text = "<= Recv data";
      break;
    case CURLINFO_SSL_DATA_IN:
      text = "<= Recv SSL data";
      break;
    case CURLINFO_SSL_DATA_OUT:
      text = "=> Send SSL data";
      break;
    default:
      break;
  }
  string dump((char *)data, size);
  cout << text << endl << dump;
  return 0;
}

size_t writeFunction(void *ptr2, size_t size, size_t nmemb, void * stream)
{
  // We assume we pass a stream so we use a stream only
  stringstream * ss = (stringstream *) stream;
  char * ptr = ( char *) ptr2;
  size_t fullSize = size*nmemb;
  ss->write( ptr, fullSize );
  return fullSize;
}

int main(void)
{
  CURL *curl;
  CURLcode res;

  curl = curl_easy_init();
  if (curl) {

    struct curl_slist *hdrs = NULL;

    yutString ycaStr;
    char *yca_cert = yca_get_cert_once("yahoo.mail.asc.all");
    if (yca_cert) {

      ycaStr = yca_cert;
      free(yca_cert);
      cout << "yca cert: " << ycaStr << endl;

      yutString appAuthStr("Yahoo-App-Auth: ");
      appAuthStr += ycaStr;
      hdrs = curl_slist_append(hdrs, appAuthStr.c_str());
      curl_easy_setopt(curl, CURLOPT_HTTPHEADER, hdrs);
    }
    else {

      cout << "yca cert not found" << endl;
    }


    /*
    yutString appAuthStr("Yahoo-App-Auth: ");
    appAuthStr += "someappcertificate-dlakdjfdalskjd1093309";
    hdrs = curl_slist_append(hdrs, appAuthStr.c_str());
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, hdrs);
*/
    curl_easy_setopt(curl, CURLOPT_VERBOSE , 1);
    curl_easy_setopt(curl, CURLOPT_DEBUGFUNCTION, TraceFunction);

    // Preparing activate request
    yutString ei("alpo_test01%40exlab.corp.gq1.yahoo.com");
    cout << "ei: " << ei << endl;
    yutString emailid(EMAILID);
    emailid.escapeUri();
    char *curlEsc = curl_easy_escape(curl, emailid.c_str(), 0);
    emailid = yutString(curlEsc);
    curl_free(curlEsc);
    cout << "Escaped emaiid: " << emailid << endl;
    yutString req_url(WS_URL);
    req_url = req_url + emailid + DEACTIVATE_REQ;
    curl_easy_setopt(curl, CURLOPT_URL, req_url.c_str());

    curl_easy_setopt(curl, CURLOPT_POST, 1L);
    Json::Value request;
    Json::FastWriter fastWriter;
    request["yid"] = "abcedeg";
    request["extacct"]["email"] = "abcd@gmail.com";
    request["extacct"]["type"] = "imap";
    yutString postDataStr(fastWriter.write(request));
    cout << "Post Data: " << postDataStr << endl;
    // postDataStr.escapeUri();
    // Send zero byte data
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, NULL);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, 0L);

    stringstream respData;
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, writeFunction);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void *)&respData);

    // Replace default Content-Type hdr
    //hdrs = curl_slist_append(hdrs, "Content-Type: application/json");
    hdrs = curl_slist_append(hdrs, "Content-Type:");

    res = curl_easy_perform(curl);

    // Get response code
    long http_code = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);
    curl_slist_free_all(hdrs);
    curl_easy_cleanup(curl);

    cout << "-------resp--------" << endl << "code: " << http_code << endl << respData.str() << endl;

    if (res != CURLE_OK) {

      cout << "curl_easy_perform failed: " << curl_easy_strerror(res) << endl;
    }

    Json::Value resp;
    Json::Reader reader;

    if (reader.parse(respData.str(), resp)) {

      cout << "Response parsed successfully" << endl;
    }

  }
  else {

    cout << "curl_easy_init failed" << endl;
  }
  return 0;
}
