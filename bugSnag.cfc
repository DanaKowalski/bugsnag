component name="bugSnag" {
	variables.app_name 				= "Bugsnag Project";
	variables.app_version 			= "1.0";
	variables.app_url 				= "http://bugsnag.com";
	// bugsnag api info
	variables.api_base_url 			= "https://notify.bugsnag.com/";
	variables.api_payload_version 	= "5";
	variables.api_key				= "";
	variables.environment			= "";
	
	public bugSnag function init(
		required string api_key,
		required string environment
	){
		
		for(local.key in arguments){
			if(arguments.keyExists(key)){
				variables[key] = arguments[key];
			}
		}

		return this;
	}

	public struct function notify_bug(
		required any exception,
		string severity = 'info',
		string app_context = cgi.script_name,
		struct user = {}
	){	
		local.return_data = {success: false, errors: [], response: {}};
		
		try {
			local.scopes = getScopesFacade();

			local.tag_context = (arguments.exception.keyExists("tagContext")) ? arguments.exception.tagContext : {};

			local.payload = {
				"notifier": {
					"name"          : variables.app_name,
					"version"       : variables.app_version,
					"url"           : variables.app_url
				},
				"events" 			: [{
					"exceptions": [{
						"errorClass": (arguments.exception.keyExists("type")) ? arguments.exception.type: '',
						"message"	: (arguments.exception.keyExists("message")) ? arguments.exception.message: 'N/a',
						"stacktrace": local.tag_context
					}],
					"severity" 		: lcase(arguments.severity),
					"user"			: arguments.user,
					// application 
					"app": {
						"version"       : '',
						"type"          : '',
						"releaseStage"	: variables.app_version
					},
					// client and server info together
					"device": {
						// OS running app
						"osName"            : local.scopes.server.os.name,
						"hostname"          : local.scopes.cgi.http_host,
						"browserVersion"    : local.scopes.cgi.http_user_agent
					},
					// identifier application section
					"context" 	: arguments.app_context,
					"request"  	: {
						// url: full URL where this event occurred, no query string
						"url" 			: listFirst(local.scopes.cgi.http_url, "?" ),
						"httpMethod" 	: local.scopes.cgi.request_method,
						"headers" 		: local.scopes.headers,
						"clientIp" 		: local.scopes.cgi.remote_addr,
						"referer"       : local.scopes.cgi.http_referer,
						"metaData": {
							"POST"    	: local.scopes.form,
							"GET" 		: local.scopes.url
						}
					},
					"breadcrumbs": [],
					"threads": [],
					// Custom metadata
					"metaData" : {

					}
				}]
			};
		}
		catch(any err){
			return_data.errors.append(err.message & " - " & err.detail);
		}

		if(!return_data.errors.len()){
			try {
				local.send_date_time = DateTimeFormat( dateConvert( "local2utc", now() ),'yyyy-mm-ddTHH:nn:ssZ');
				local.http_call = new HTTP(url=variables.api_base_url, method="post");

				local.http_call.addParam(type="body", value=serializeJSON(payload));

				local.http_call.addParam(type="header", name="Content-Type", value="application/json");
				local.http_call.addParam(type="header", name="Bugsnag-Payload-Version", value=variables.api_payload_version);
				local.http_call.addParam(type="header", name="Bugsnag-Api-Key", value=variables.api_key);
				local.http_call.addParam(type="header", name="Bugsnag-Sent-At", value=local.send_date_time);
				
				return_data.response = local.http_call.send().getPrefix();

				if(local.return_data.response.keyExists("statusCode") && local.return_data.response.statusCode.find("200")){
					local.return_data.success = true;
				}
			}
			catch(any err){
				local.return_data.errors.append(err.message & " - " & err.detail);
			}
		}

		return local.return_data;
	}

	/**
	* 	getScopesFacade() - prevents breaking encapsulation on main function
	**/
	private struct function getScopesFacade(
	){	
		try {
			local.http_headers = getHttpRequestData().headers;
		}
		catch(any err){
			local.http_headers = {};
		}

		return {
			application: (isDefined("appication")) ? application : {},
			server: (isDefined("server")) ? server : {},
			cgi: (isDefined("cgi")) ? cgi : {},
			request: (isDefined("cgi")) ? cgi : {},
			form: (isDefined("form")) ? sanitize_scope_data(form) : {},
			url: (isDefined("url")) ? sanitize_scope_data(url) : {},
			session: (isDefined("session")) ? session : {},
			headers: local.http_headers
		};
	}

	private function sanitize_scope_data(
		required struct scope
	){
		local.returnData = duplicate(arguments.scope);

		for(local.item in returnData){
			returnData[item] = encodeForHTML(item);
		}

		return returnData;
	}
}