#if defined _solarisapi_client_request_included
 #endinput
#endif
#define _solarisapi_client_request_included

#define REQ_CONFIG_URL                      "url"
#define REQ_CONFIG_METHOD                   "method"
#define REQ_CONFIG_DATA                     "data"
#define REQ_CONFIG_SUCCESS_STATUS           "status_success"
#define REQ_CONFIG_SUCCESS_CALLBACK         "success_callback"
#define REQ_CONFIG_POST_SUCCESS_CALLBACK    "post_success_callback"

#include <ripext>

typeset HTTPRequestSuccessCallback {
    function void (HTTPResponse respone, HTTPRequestConfig config, any data);
};

/**
 * Use Bearer Authorization header for request
 * 
 * @param request     HTTPRequest
 * @return            HTTPRequest (same as passed)
 */
HTTPRequest UseBearerAuthorization(HTTPRequest request) {
    request.SetHeader("Authorization", SAPI_AUTHORIZAION_HEADER);
    return request;
}

/**
 * Create request with default settings
 * 
 * @param url         Request URL
 * @return            HTTPRequest
 */
HTTPRequest CreateHTTPRequest(const char[] url) {
    HTTPRequest request = new HTTPRequest(url);
    request.ConnectTimeout = 6;
    return UseBearerAuthorization(request);
}

methodmap HTTPRequestConfig < StringMap {
    /**
     * HTTPStatus of a successful request
     */
    property HTTPStatus StatusSuccess {
        public get() {
            HTTPStatus status;
            if (!this.GetValue(REQ_CONFIG_SUCCESS_STATUS, status)) status = HTTPStatus_OK;
            return status;
        }
        public set(HTTPStatus status) { this.SetValue(REQ_CONFIG_SUCCESS_STATUS, status); }
    }
    
    /**
     * Request JSON payload (if supplied)
     */
    property JSON Data {
        public get() {
            JSON data;
            this.GetValue(REQ_CONFIG_DATA, data);
            return data;
        }
        public set(JSON data) {
            if (data) this.SetValue(REQ_CONFIG_DATA, CloneHandle(data));
            else this.SetValue(REQ_CONFIG_DATA, 0);
        }
    }
    
    /**
     * Set Request URL
     * 
     * @param url                       Request URL
     */
    public HTTPRequestConfig SetUrl(const char[] url) {
        this.SetString(REQ_CONFIG_URL, url, true);
        return this;
    }

    /**
     * Get Request URL
     * 
     * @param szBuffer                   Buffer to write URL to
     * @param iMaxlength                 Size of the buffer
     */
    public void GetUrl(char[] szBuffer, int iMaxlength) {
        this.GetString(REQ_CONFIG_URL, szBuffer, iMaxlength);
    }

    public HTTPRequestConfig SetMethod(const char[] method) {
        this.SetString(REQ_CONFIG_METHOD, method, true);
        return this;
    }

    /**
     * Get HTTP method name
     * 
     * @param szBuffer                   Buffer to write HTTP method name to
     * @param iMaxlength                 Size of the buffer
     */
    public void GetMethod(char[] szBuffer, int iMaxlength) {
        this.GetString(REQ_CONFIG_METHOD, szBuffer, iMaxlength);
    }

    /**
     * Write request URL, HTTP method and success status code to string
     * 
     * @param szBuffer                   Buffer to write
     * @param iMaxlength                 Size of the buffer
     */
    public void ToString(char[] szBuffer, int iMaxlength) {
        char szUrl[2000];
        char szMethod[16];
        this.GetUrl(szUrl, sizeof(szUrl));
        this.GetMethod(szMethod, sizeof(szMethod));
        Format(szBuffer, iMaxlength, "url = %s, method = %s, success_status = %i", szUrl, szMethod, this.StatusSuccess);
    }

    /**
     * Set success callback for request
     * 
     * @param cb                         HTTPRequestSuccessCallback
     */
    public HTTPRequestConfig OnSuccess(HTTPRequestSuccessCallback cb) {
        PrivateForward fwd;
        this.GetValue(REQ_CONFIG_SUCCESS_CALLBACK, fwd);
        if (fwd) delete fwd;
        fwd = new PrivateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
        fwd.AddFunction(null, cb);
        this.SetValue(REQ_CONFIG_SUCCESS_CALLBACK, fwd, true);
        return this;
    }

    /**
     * Constructor
     * 
     * @param url                        Request URL
     * @param method                     HTTP method (for logging)
     * @param succcess                   HTTPStatus of a successful request
     */
    public HTTPRequestConfig(const char[] url, const char[] method, HTTPStatus success = HTTPStatus_OK) {
        HTTPRequestConfig self = view_as<HTTPRequestConfig>(new StringMap());
        self.StatusSuccess = success;
        self.SetUrl(url);
        self.SetMethod(method);
        return self;
    }

    /**
     * "Destructor". Required to close open handles
     */
    public void Destruct() {
        JSON data;
        this.GetValue(REQ_CONFIG_DATA, data);
        delete data;
        PrivateForward fwd;
        this.GetValue(REQ_CONFIG_SUCCESS_CALLBACK, fwd);
        if (fwd) delete fwd;
        this.Clear();
    }
}