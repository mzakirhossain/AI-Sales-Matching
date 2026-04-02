public with sharing class AIService {

	// AIService 

	private static String callOpenAI(String prompt) {

        // 🔹 Read from metadata
        API_Config__mdt config = API_Config__mdt.getInstance('OpenAI');

        if (config == null) {
            throw new CalloutException('Missing API Config Metadata');
        }

        String endpoint = config.Base_URL__c;
        String apiKey = config.API_Key__c;

        // 🔹 Prepare request
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
		
		// 🔥 increase timeout (max 120000 ms = 120 sec)
		req.setTimeout(120000);
		
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + apiKey);

        // 🔹 Body (NEW OpenAI format)
        Map<String, Object> body = new Map<String, Object>{
            'model' => 'gpt-5-nano',
            'input' => prompt,
            'store' => true
        };

        req.setBody(JSON.serialize(body));

        // 🔹 Send request
        Http http = new Http();
        HttpResponse res = http.send(req);

		Map<String, Object> result =
		(Map<String, Object>) JSON.deserializeUntyped(res.getBody());


		String aiText = '';

		List<Object> output = (List<Object>) result.get('output');

		for (Object obj : output) {
			Map<String, Object> item = (Map<String, Object>) obj;

			if (item.get('type') == 'message') {

				List<Object> content = (List<Object>) item.get('content');

				if (content != null && !content.isEmpty()) {

					for (Object c : content) {
						Map<String, Object> cMap = (Map<String, Object>) c;

						if (cMap.get('type') == 'output_text') {
							aiText = (String) cMap.get('text');
							break;
						}
					}
				}
			}
		}

		System.debug('PARSED TEXT: ' + aiText);
		System.debug('FULL RESPONSE: ' + res.getBody());

		// List<Object> choices = (List<Object>) result.get('choices');
		// Map<String, Object> msg = (Map<String, Object>) ((Map<String, Object>)choices[0]).get('message');

		Map<String, Object> msg =
			(Map<String, Object>) JSON.deserializeUntyped(aiText);

		return aiText;// (String) msg.get('msg');
	}	

		public static Map<String, Object> extractLead(String description) {

			String prompt =
			'You are a data extraction API.\n' +
			'Return ONLY valid JSON. No explanation.\n\n' +
			'Format:\n' +
			'{\n' +
			'  "team_size": number,\n' +
			'  "location": string,\n' +
			'  "preferences": string[]\n' +
			'}\n\n' +
			'Text:\n' + description;			

			String response = callOpenAI(prompt);

			return (Map<String, Object>) JSON.deserializeUntyped(response);
		}

	
		public static Map<String, Object> generateMatch(
			Lead l,
			List<Property_Listing__c> listings,
			List<User> users
		) {

			String prompt = buildPrompt(l, listings, users);

			String response = callOpenAI(prompt);

			return (Map<String, Object>) JSON.deserializeUntyped(response);
		}

	private static String buildPrompt(
		Lead l,
		List<Property_Listing__c> listings,
		List<User> users
	) {

		// 🔹 Limit listings (avoid token overflow)
		Integer maxListings = Math.min(5, listings.size());

		List<String> listingStrings = new List<String>();

		for (Integer i = 0; i < maxListings; i++) {
			Property_Listing__c p = listings[i];

			listingStrings.add(
				'Name: ' + p.Name +
				', Capacity: ' + p.Capacity__c +
				', Area: ' + p.Area__c +
				', Price: ' + p.price_per_desk__c
			);
		}

		// 🔹 Users
		List<String> userStrings = new List<String>();
		for (User u : users) {
			userStrings.add(
				u.Name + ' (' + u.Speciality__c + ')'
			);
		}

		// 🔹 Related Accounts (same industry or name match)
		List<Account> accounts = [
			SELECT Name, Industry, BillingCity, Owner_Name__c
			FROM Account
			WHERE Industry = :l.Industry
			LIMIT 3
		];

		List<String> accountStrings = new List<String>();
		for (Account a : accounts) {
			accountStrings.add(
				a.Name + ' - ' + a.Industry + ' - ' + a.BillingCity +
				' (Owner: ' + a.Owner_Name__c + ')'
			);
		}

		// 🔹 Opportunities insights
		List<Opportunity> opps = [
			SELECT Name, StageName, Loss_Reason__c, Amount
			FROM Opportunity
			WHERE StageName = 'Closed Lost'
			LIMIT 3
		];

		List<String> oppStrings = new List<String>();
		for (Opportunity o : opps) {
			oppStrings.add(
				o.Name + ' - Lost Reason: ' + o.Loss_Reason__c +
				' - Amount: ' + o.Amount
			);
		}

		// 🔥 FINAL PROMPT
		String prompt =
			'You are an AI-powered commercial real estate sales assistant.\n\n' +

			'OBJECTIVE:\n' +
			'1. Match the lead to top 3 listings\n' +
			'2. Assign best agent\n' +
			'3. Determine priority (High/Medium/Low)\n' +
			'4. Provide reasoning and insight\n\n' +

			'LEAD:\n' +
			'Name: ' + l.Name + '\n' +
			'Company: ' + l.Company + '\n' +
			'Industry: ' + l.Industry + '\n' +
			'Description: ' + l.Description + '\n\n' +

			'AVAILABLE LISTINGS:\n' +
			String.join(listingStrings, '\n') + '\n\n' +

			'AVAILABLE AGENTS:\n' +
			String.join(userStrings, '\n') + '\n\n' +

			'SIMILAR ACCOUNTS:\n' +
			(String.isBlank(String.join(accountStrings, '\n')) ? 'None' : String.join(accountStrings, '\n')) + '\n\n' +

			'PAST LOST OPPORTUNITIES:\n' +
			(String.isBlank(String.join(oppStrings, '\n')) ? 'None' : String.join(oppStrings, '\n')) + '\n\n' +

			'IMPORTANT RULES:\n' +
			'- Match based on team size, location, and preferences\n' +
			'- Consider past lost deals (e.g., pricing issues)\n' +
			'- Prefer agents with relevant speciality\n' +
			'- Be concise but insightful\n\n' +

			'OUTPUT STRICT JSON ONLY. NO EXTRA TEXT.\n' +
			'{\n' +
			'  "priority": "High/Medium/Low",\n' +
			'  "assigned_agent": "Agent Name",\n' +
			'  "confidence": 0-100,\n' +
			'  "top_listings": [\n' +
			'    {\n' +
			'      "name": "Listing Name",\n' +
			'      "score": 0-100,\n' +
			'      "reasons": ["reason1", "reason2"]\n' +
			'    }\n' +
			'  ],\n' +
			'  "insight": "Sales insight"\n' +
			'}';

		return prompt;
	}


	public static List<String> refineListingsWithAI(
    Map<String, Object> extracted,
    List<Property_Listing__c> listings
		) {

			List<String> listingData = new List<String>();

			for (Property_Listing__c p : listings) {
				listingData.add(
					'Name: ' + p.Name +
					', Area: ' + p.Area__c +
					', Capacity: ' + p.Capacity__c +
					', Price: ' + p.price_per_desk__c +
					', Amenities: ' + p.Amenities__c +
					', Notes: ' + p.Notes__c
				);
			}

	String prompt =
		'You are an expert commercial real estate assistant.\n\n' +

		'FILTER THE BEST 3 LISTINGS based on:\n' +
		'- team size\n' +
		'- location\n' +
		'- preferences\n' +
		'- value for money\n\n' +

		'LEAD REQUIREMENTS:\n' +
		JSON.serialize(extracted) + '\n\n' +

		'LISTINGS:\n' +
		String.join(listingData, '\n') + '\n\n' +

		'Return ONLY JSON:\n' +
		'{ "top_listings": ["Listing Name 1", "Listing Name 2", "Listing Name 3"] }';

			String response = callOpenAI(prompt);

			Map<String, Object> parsed =
				(Map<String, Object>) JSON.deserializeUntyped(response);


			List<Object> names = (List<Object>) parsed.get('top_listings');

			List<String> result = new List<String>();

			for (Object o : names) {
				result.add(String.valueOf(o));
			}

			return result;
		}
}