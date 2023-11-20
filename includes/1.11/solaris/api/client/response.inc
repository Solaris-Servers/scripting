#if defined _solarisapi_client_response_included
 #endinput
#endif
#define _solarisapi_client_response_included

#include <solaris/api/client/request>

/**
 * Middleware to handle request/response errors and HTTPRequestConfig lifeycle.
 * Every response must go through it.
 * 
 * @param res             HTTPResponse
 * @param value           HTTPRequestConfig
 * @param szClientErr     HTTP client error during request
 */
stock void HTTPResponseMiddleware(HTTPResponse res, any value, const char[] szClientErr) {
    HTTPRequestConfig req = view_as<HTTPRequestConfig>(value);
    
    bool isSuccess = true;
    char szUrl[2000];
    char szHttpMethod[16];
    char szReqData[2048];
    PrivateForward successFwd;

    req.GetUrl(szUrl, sizeof(szUrl));
    req.GetMethod(szHttpMethod, sizeof(szHttpMethod));
    req.GetValue(REQ_CONFIG_SUCCESS_CALLBACK, successFwd);
    if (req.Data) {
        req.Data.ToString(szReqData, sizeof(szReqData));
    }

    // error sending request
    if (strlen(szClientErr) > 0) {
        isSuccess = false;
        LogError("%s %s: %s\nData: %s", szHttpMethod, szUrl, szClientErr, szReqData);
    }
    // error response from the server
    if (isSuccess && res.Status != req.StatusSuccess) {
        isSuccess = false;
        char szResponseErr[2048];
        res.Data.ToString(szResponseErr, sizeof(szResponseErr));
        LogError("%s %s [%i]: %s\nData: %s", szHttpMethod, szUrl, res.Status, szResponseErr, szReqData);
    }
    // has success callback
    if (isSuccess && successFwd) {
        Call_StartForward(successFwd);
        Call_PushCell(res);
        Call_PushCell(req);
        Call_PushCell(res.Data);
        Call_Finish();
    }

    req.Destruct();
    delete req;
}