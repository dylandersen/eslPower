public with sharing class AccountIntelligence {
    /**
     * Main invocable method to analyze account using AI
     * @param requests List of requests containing the account ID to analyze
     * @return List of formatted analysis results
     */
    @InvocableMethod(
      label='Analyze Account'
      description='Analyzes account health with AI-powered intelligence across 6 dimensions'
    )
    public static List<AnalysisResult> analyzeAccount(
      List<AnalysisRequest> requests
    ) {
      List<AnalysisResult> results = new List<AnalysisResult>();
  
      if (requests == null || requests.isEmpty()) {
        AnalysisResult errorResult = new AnalysisResult();
        errorResult.analysisText = 'No account ID provided for analysis.';
        results.add(errorResult);
        return results;
      }
  
      AnalysisRequest request = requests[0];
      String accountId = request.accountId;
  
      // Query the account data
      List<Account> accountList = queryAccountData(accountId);
  
      if (accountList.isEmpty()) {
        AnalysisResult errorResult = new AnalysisResult();
        errorResult.analysisText =
          'Account not found with ID: ' + accountId;
        results.add(errorResult);
        return results;
      }
  
      Account account = accountList[0];
  
      // Query opportunity history
      OpportunityHistory oppHistory = queryOpportunityHistory(accountId);
  
      // Query case history
      CaseHistory caseHistory = queryCaseHistory(accountId);
  
      // Query activity timeline
      ActivityTimeline timeline = queryActivityTimeline(accountId);
  
      // Find similar successful accounts for benchmarking
      List<Account> similarAccounts = findSimilarAccounts(account);
  
      // Build the AI prompt
      String promptText = buildAnalysisPrompt(account, oppHistory, caseHistory, timeline, similarAccounts);
  
      // Call the Salesforce Models API for AI-powered analysis
      String htmlResponse = callSalesforceAI(promptText);
  
      AnalysisResult result = new AnalysisResult();
      result.analysisText = htmlResponse;
      results.add(result);
  
      return results;
    }
  
    /**
     * Query account data
     * @param accountId The account ID to query
     * @return List of Account records with related details
     */
    private static List<Account> queryAccountData(String accountId) {
      return [
        SELECT
          Id,
          Name,
          Industry,
          Type,
          AnnualRevenue,
          NumberOfEmployees,
          CreatedDate,
          BillingCity,
          BillingState,
          BillingCountry
        FROM Account
        WHERE Id = :accountId
        LIMIT 1
      ];
    }
  
    /**
     * Query opportunity history for the account
     * @param accountId The account ID to query opportunities for
     * @return OpportunityHistory wrapper containing all opportunities
     */
    private static OpportunityHistory queryOpportunityHistory(String accountId) {
      OpportunityHistory history = new OpportunityHistory();
  
      // Query all opportunities for the account
      history.allOpportunities = [
        SELECT
          Id,
          Name,
          Amount,
          StageName,
          Type,
          CloseDate,
          IsWon,
          IsClosed,
          Probability,
          CreatedDate
        FROM Opportunity
        WHERE AccountId = :accountId
        ORDER BY CreatedDate DESC
        LIMIT 500
      ];
  
      // Calculate metrics
      history.totalOpportunities = history.allOpportunities.size();
      history.totalWonOpportunities = 0;
      history.totalOpenOpportunities = 0;
      history.totalPipelineValue = 0;
      history.totalACV = 0;
      
      for (Opportunity opp : history.allOpportunities) {
        if (opp.IsWon) {
          history.totalWonOpportunities++;
          if (opp.Amount != null) {
            history.totalACV += opp.Amount;
          }
        } else if (!opp.IsClosed) {
          history.totalOpenOpportunities++;
          if (opp.Amount != null) {
            history.totalPipelineValue += opp.Amount;
          }
        }
      }
  
      if (history.totalOpportunities > 0) {
        history.winRate = (Decimal.valueOf(history.totalWonOpportunities) / Decimal.valueOf(history.totalOpportunities)) * 100;
        if (history.totalWonOpportunities > 0) {
          history.averageDealSize = history.totalACV / history.totalWonOpportunities;
        }
      }
  
      return history;
    }
  
    /**
     * Query case history for the account
     * @param accountId The account ID to query cases for
     * @return CaseHistory wrapper containing all cases
     */
    private static CaseHistory queryCaseHistory(String accountId) {
      CaseHistory history = new CaseHistory();
  
      // Query all cases for the account
      history.allCases = [
        SELECT
          Id,
          CaseNumber,
          Subject,
          Priority,
          Status,
          CreatedDate,
          ClosedDate,
          Origin
        FROM Case
        WHERE AccountId = :accountId
        ORDER BY CreatedDate DESC
        LIMIT 500
      ];
  
      // Calculate metrics
      history.totalCases = history.allCases.size();
      history.openCases = 0;
      history.resolvedCases = 0;
      history.totalResolutionDays = 0;
  
      for (Case c : history.allCases) {
        if (c.Status == 'Closed' || c.Status == 'Resolved') {
          history.resolvedCases++;
          if (c.CreatedDate != null && c.ClosedDate != null) {
            Integer daysDiff = c.CreatedDate.date().daysBetween(c.ClosedDate.date());
            history.totalResolutionDays += daysDiff;
          }
        } else {
          history.openCases++;
        }
      }
  
      if (history.resolvedCases > 0) {
        history.averageResolutionDays = history.totalResolutionDays / history.resolvedCases;
      }
  
      return history;
    }
  
    /**
     * Query activity timeline including emails, tasks, and events
     * @param accountId The account ID to query activities for
     * @return ActivityTimeline wrapper containing all activities
     */
    private static ActivityTimeline queryActivityTimeline(String accountId) {
      ActivityTimeline timeline = new ActivityTimeline();
  
      Date startDate = Date.today().addDays(-90);
  
      // Query recent emails (last 90 days)
      try {
        timeline.emails = [
          SELECT Subject, CreatedDate, Status, RelatedToId
          FROM EmailMessage
          WHERE RelatedToId = :accountId
            AND CreatedDate >= :startDate
          ORDER BY CreatedDate DESC
          LIMIT 100
        ];
      } catch (Exception e) {
        timeline.emails = new List<EmailMessage>();
      }
  
      // Query tasks (last 90 days)
      timeline.tasks = [
        SELECT Subject, Status, ActivityDate, Priority, Description
        FROM Task
        WHERE WhatId = :accountId
          AND ActivityDate >= :startDate
        ORDER BY ActivityDate DESC
        LIMIT 100
      ];
  
      // Query events (last 90 days)
      timeline.events = [
        SELECT Subject, StartDateTime, EndDateTime, Description
        FROM Event
        WHERE WhatId = :accountId
          AND StartDateTime >= :startDate
        ORDER BY StartDateTime DESC
        LIMIT 100
      ];
  
      // Calculate engagement metrics
      timeline.totalEmails = timeline.emails.size();
      timeline.totalTasks = timeline.tasks.size();
      timeline.totalEvents = timeline.events.size();
      timeline.totalActivities = timeline.totalEmails + timeline.totalTasks + timeline.totalEvents;
  
      // Find most recent activity
      if (!timeline.emails.isEmpty()) {
        timeline.mostRecentEmailDate = timeline.emails[0].CreatedDate.date();
      }
      if (!timeline.events.isEmpty() && timeline.events[0].StartDateTime != null) {
        if (timeline.mostRecentActivityDate == null || 
            timeline.events[0].StartDateTime.date() > timeline.mostRecentActivityDate) {
          timeline.mostRecentActivityDate = timeline.events[0].StartDateTime.date();
        }
      }
  
      return timeline;
    }
  
    /**
     * Find similar successful accounts for benchmarking
     * @param account The current account to find similar ones
     * @return List of similar accounts
     */
    private static List<Account> findSimilarAccounts(Account account) {
      try {
        // Find accounts with similar industry and type, excluding current account
        List<Account> similar = [
          SELECT Id, Name, Industry, Type, AnnualRevenue, NumberOfEmployees
          FROM Account
          WHERE Id != :account.Id
            AND Industry = :account.Industry
            AND Type = :account.Type
            AND AnnualRevenue != null
          ORDER BY AnnualRevenue DESC
          LIMIT 10
        ];
        return similar;
      } catch (Exception e) {
        return new List<Account>();
      }
    }
  
    /**
     * Build the complete AI prompt for account analysis
     * @param account - The account to analyze
     * @param oppHistory - The opportunity history
     * @param caseHistory - The case history
     * @param timeline - The activity timeline
     * @param similarAccounts - Similar accounts for benchmarking
     * @return Complete prompt text for AI analysis
     */
    private static String buildAnalysisPrompt(
      Account account,
      OpportunityHistory oppHistory,
      CaseHistory caseHistory,
      ActivityTimeline timeline,
      List<Account> similarAccounts
    ) {
      List<String> promptParts = new List<String>();
  
      promptParts.add(
        'You are an expert Account Manager with 15+ years of experience managing enterprise accounts.\\n\\n'
      );
      promptParts.add(
        '**IMPORTANT CONTEXT:** Today is ' +
          Date.today().format() +
          '. Use this current date to properly assess whether dates are in the past, present, or future.\\n\\n'
      );
  
      promptParts.add('## CURRENT ACCOUNT\\n');
      promptParts.add(
        '- **Account Name:** ' +
          (String.isNotBlank(account.Name) ? account.Name : 'N/A') +
          '\\n'
      );
      promptParts.add(
        '- **Industry:** ' +
          (String.isNotBlank(account.Industry)
            ? account.Industry
            : 'Not specified') +
          '\\n'
      );
      promptParts.add(
        '- **Type:** ' +
          (String.isNotBlank(account.Type) ? account.Type : 'Not specified') +
          '\\n'
      );
      promptParts.add(
        '- **Annual Revenue:** ' +
          (account.AnnualRevenue != null
            ? '$' + String.valueOf(account.AnnualRevenue.format())
            : 'Not specified') +
          '\\n'
      );
      promptParts.add(
        '- **Employees:** ' +
          (account.NumberOfEmployees != null
            ? String.valueOf(account.NumberOfEmployees)
            : 'Not specified') +
          '\\n'
      );
      
      if (account.CreatedDate != null) {
        Integer yearsOld = account.CreatedDate.date().daysBetween(Date.today()) / 365;
        promptParts.add(
          '- **Account Age:** ' + String.valueOf(yearsOld) + ' years\\n'
        );
      }
  
      // Opportunity Analysis
      promptParts.add('\\n## OPPORTUNITY ANALYSIS\\n');
      promptParts.add(
        '- **Total Opportunities:** ' + String.valueOf(oppHistory.totalOpportunities) + '\\n'
      );
      promptParts.add(
        '- **Won Opportunities:** ' +
          String.valueOf(oppHistory.totalWonOpportunities) +
          ' (' +
          (oppHistory.winRate != null
            ? String.valueOf(oppHistory.winRate.round())
            : '0') +
          '% win rate)\\n'
      );
      promptParts.add(
        '- **Open Pipeline Value:** ' +
          (oppHistory.totalPipelineValue > 0
            ? '$' + String.valueOf(oppHistory.totalPipelineValue.format())
            : '$0') +
          '\\n'
      );
      promptParts.add(
        '- **Total Contract Value (ACV):** ' +
          (oppHistory.totalACV > 0
            ? '$' + String.valueOf(oppHistory.totalACV.format())
            : '$0') +
          '\\n'
      );
      if (oppHistory.averageDealSize != null && oppHistory.averageDealSize > 0) {
        promptParts.add(
          '- **Average Deal Size:** ' +
            '$' +
            String.valueOf(oppHistory.averageDealSize.format()) +
            '\\n'
        );
      }
  
      // Case Analysis
      promptParts.add('\\n## CASE/SUPPORT ANALYSIS\\n');
      promptParts.add(
        '- **Total Cases:** ' + String.valueOf(caseHistory.totalCases) + '\\n'
      );
      promptParts.add(
        '- **Open Cases:** ' + String.valueOf(caseHistory.openCases) + '\\n'
      );
      promptParts.add(
        '- **Resolved Cases:** ' +
          String.valueOf(caseHistory.resolvedCases) +
          '\\n'
      );
      if (caseHistory.averageResolutionDays != null && caseHistory.averageResolutionDays > 0) {
        promptParts.add(
          '- **Average Resolution Time:** ' +
            String.valueOf(caseHistory.averageResolutionDays.round()) +
            ' days\\n'
        );
      }
  
      // Activity Engagement
      promptParts.add('\\n## ACTIVITY ENGAGEMENT (Last 90 Days)\\n');
      promptParts.add(
        '- **Total Activities:** ' +
          String.valueOf(timeline.totalActivities) +
          ' (Emails: ' +
          String.valueOf(timeline.totalEmails) +
          ', Tasks: ' +
          String.valueOf(timeline.totalTasks) +
          ', Meetings: ' +
          String.valueOf(timeline.totalEvents) +
          ')\\n'
      );
      
      if (timeline.mostRecentActivityDate != null) {
        Integer daysSinceLastActivity = timeline.mostRecentActivityDate.daysBetween(Date.today());
        promptParts.add(
          '- **Days Since Last Activity:** ' +
            String.valueOf(daysSinceLastActivity) +
            ' days\\n'
        );
      }
  
      // Similar Accounts Benchmarking
      if (!similarAccounts.isEmpty()) {
        promptParts.add('\\n## SIMILAR ACCOUNTS FOR BENCHMARKING\\n');
        promptParts.add(
          'Found ' +
            String.valueOf(similarAccounts.size()) +
            ' similar accounts for comparison.\\n\\n'
        );
        for (Account similar : similarAccounts) {
          promptParts.add(
            '- ' +
              similar.Name +
              ' (Revenue: ' +
              (similar.AnnualRevenue != null
                ? '$' + String.valueOf(similar.AnnualRevenue.format())
                : 'N/A') +
              ')\\n'
          );
        }
      }
  
      // Scoring instructions
      promptParts.add('\\n## SCORING CRITERIA\\n');
      promptParts.add(
        'Provide analysis across 6 dimensions using standardized High (Green) / Medium (Yellow) / Low (Red) scoring:\\n\\n'
      );
      promptParts.add('### 1. Overall Health Score (0-100 points)\\n');
      promptParts.add(
        '- High (Green) - 80-100: Account is healthy and thriving\\n'
      );
      promptParts.add(
        '- Medium (Yellow) - 60-79: Account needs attention and nurturing\\n'
      );
      promptParts.add(
        '- Low (Red) - 0-59: Account at risk, immediate action required\\n\\n'
      );
      
      promptParts.add('### 2. Renewal Risk Assessment\\n');
      promptParts.add(
        '- High (Green): Low risk - Strong indicators for renewal success\\n'
      );
      promptParts.add(
        '- Medium (Yellow): Moderate risk - Some concerns but manageable\\n'
      );
      promptParts.add(
        '- Low (Red): High risk - Renewal at risk, intervention needed\\n\\n'
      );
      
      promptParts.add('### 3. Expansion Opportunity Score\\n');
      promptParts.add(
        '- High (Green): Strong expansion potential - Clear growth indicators\\n'
      );
      promptParts.add(
        '- Medium (Yellow): Moderate potential - Some expansion opportunities exist\\n'
      );
      promptParts.add(
        '- Low (Red): Limited potential - Focus on retention over expansion\\n\\n'
      );
      
      promptParts.add('### 4. Sales Engagement Quality\\n');
      promptParts.add(
        '- High (Green): Strong engagement - Frequent, quality interactions\\n'
      );
      promptParts.add(
        '- Medium (Yellow): Adequate engagement - Regular but could be improved\\n'
      );
      promptParts.add(
        '- Low (Red): Weak engagement - Infrequent or declining interactions\\n\\n'
      );
      
      promptParts.add('### 5. Support/Case Health\\n');
      promptParts.add(
        '- High (Green): Healthy - Low case volume, quick resolution\\n'
      );
      promptParts.add(
        '- Medium (Yellow): Moderate - Some cases but manageable\\n'
      );
      promptParts.add(
        '- Low (Red): Poor - High volume, slow resolution, frequent escalations\\n\\n'
      );
      
      promptParts.add('### 6. Revenue Intelligence\\n');
      promptParts.add(
        '- High (Green): Strong revenue - Growing ACV, healthy pipeline\\n'
      );
      promptParts.add(
        '- Medium (Yellow): Stable revenue - Consistent but limited growth\\n'
      );
      promptParts.add(
        '- Low (Red): Declining revenue - Shrinking ACV, weak pipeline\\n\\n'
      );
  
      // Calculate closed won and closed lost revenue
      Decimal closedWonRevenue = 0;
      Decimal closedLostRevenue = 0;
      Integer closedWonCount = 0;
      Integer closedLostCount = 0;
      
      for (Opportunity opp : oppHistory.allOpportunities) {
        if (opp.IsWon && opp.Amount != null) {
          closedWonRevenue += opp.Amount;
          closedWonCount++;
        } else if (opp.IsClosed && !opp.IsWon && opp.Amount != null) {
          closedLostRevenue += opp.Amount;
          closedLostCount++;
        }
      }
  
      // Output format instructions
      promptParts.add('\\n\\n## OUTPUT FORMAT INSTRUCTIONS\\n');
      promptParts.add('**CRITICAL RULES:**\\n');
      promptParts.add('1. Return ONLY clean HTML - NO markdown code blocks, NO backticks\\n');
      promptParts.add('2. Use <b>bold tags</b> for ALL key words, names, amounts, metrics, percentages, dates, and numbers\\n');
      promptParts.add('3. NEVER include brackets, examples, or placeholders like [X] or [Level] or [Analyze...]\\n');
      promptParts.add('4. Provide REAL analysis based on the data - replace all examples with actual insights\\n');
      promptParts.add('5. Write in natural language, not instructions to "provide" things\\n');
      promptParts.add('6. Use emojis for ratings: 🟢 for High, 🟡 for Medium, 🔴 for Low (NOT the words Green/Yellow/Red)\\n');
      promptParts.add('7. Add line breaks between dimension sections for better readability\\n');
      promptParts.add('8. Be SPECIFIC in explanations - cite exact data points, numbers, and trends that led to each score\\n');
      promptParts.add('9. Action items must be ACTIONABLE with specific next steps, named contacts, and concrete tasks\\n');
      promptParts.add('10. Format action items as: Main action description (minimum 3 sentences), then nested bullet points for Timeline and Priority\\n');
      promptParts.add('11. Overall Health Score: Provide a NUMBER out of 100 AND emoji color (🟢/🟡/🔴)\\n');
      promptParts.add('12. All other dimensions: Use ONLY emoji color (🟢/🟡/🔴) - no numbers\\n');
      promptParts.add('13. Each dimension description must be minimum 5 sentences with specific data points\\n\\n');
      
      promptParts.add('**START YOUR RESPONSE HERE - NO PREAMBLE:**\\n\\n');
      
      promptParts.add('<h1>🏢 Account Overview</h1><ul>');
      promptParts.add('<li><strong>Account:</strong> <b>' + account.Name + '</b></li>');
      promptParts.add(
        '<li><strong>Industry:</strong> <b>' +
          (String.isNotBlank(account.Industry) ? account.Industry : 'N/A') +
          '</b></li>'
      );
      promptParts.add(
        '<li><strong>Annual Revenue:</strong> <b>' +
          (account.AnnualRevenue != null
            ? '$' + String.valueOf(account.AnnualRevenue.format())
            : 'N/A') +
          '</b></li>'
      );
      promptParts.add(
        '<li><strong>Total Opportunities:</strong> <b>' +
          String.valueOf(oppHistory.totalOpportunities) +
          '</b></li>'
      );
      promptParts.add(
        '<li><strong>Closed Won Revenue:</strong> <b>$' +
          String.valueOf(closedWonRevenue.format()) +
          '</b> from <b>' +
          String.valueOf(closedWonCount) +
          '</b> opportunities</li>'
      );
      promptParts.add(
        '<li><strong>Closed Lost Revenue:</strong> <b>$' +
          String.valueOf(closedLostRevenue.format()) +
          '</b> from <b>' +
          String.valueOf(closedLostCount) +
          '</b> opportunities</li>'
      );
      promptParts.add(
        '<li><strong>Current Pipeline:</strong> <b>$' +
          String.valueOf(oppHistory.totalPipelineValue.format()) +
          '</b> from <b>' +
          String.valueOf(oppHistory.totalOpenOpportunities) +
          '</b> open opportunities</li>'
      );
      if (oppHistory.winRate != null && oppHistory.winRate > 0) {
        promptParts.add(
          '<li><strong>Win Rate:</strong> <b>' +
            String.valueOf(oppHistory.winRate.round()) +
            '%</b></li>'
        );
      }
      promptParts.add('</ul>');
  
      promptParts.add('<hr/><h1>📊 Health Score Analysis</h1>');
      promptParts.add('<h2>🎯 Overall Health Score</h2>');
      promptParts.add('<br/>');
      promptParts.add('<h2>1️⃣ Renewal Risk Assessment</h2>');
      promptParts.add('<br/>');
      promptParts.add('<h2>2️⃣ Expansion Opportunity Score</h2>');
      promptParts.add('<br/>');
      promptParts.add('<h2>3️⃣ Sales Engagement Quality</h2>');
      promptParts.add('<br/>');
      promptParts.add('<h2>4️⃣ Case Health</h2>');
      promptParts.add('<br/>');
      promptParts.add('<h2>5️⃣ Revenue Intelligence</h2>');
      promptParts.add('<br/>');
      
      promptParts.add('<hr/><h1>✅ Recommended Action Items</h1>');
      promptParts.add('<p><strong>Format each action item as (minimum 3 sentences for main description):</strong></p>');
      promptParts.add('<ul>');
      promptParts.add('<li>Main action description (minimum 3 sentences)</li>');
      promptParts.add('<ul>');
      promptParts.add('<li>Timeline: [specific timeframe]</li>');
      promptParts.add('<li>Priority: [emoji] [High/Medium/Low]</li>');
      promptParts.add('</ul>');
      promptParts.add('</ul>');
  
      return String.join(promptParts, '');
    }
  
    /**
     * Calls the Salesforce Models API to perform AI-powered analysis
     * @param promptText The formatted prompt containing the account data
     * @return AI-generated analysis response
     */
    private static String callSalesforceAI(String promptText) {
      try {
        // Use the default OpenAI GPT-4o mini model
        String modelName = 'sfdc_ai__DefaultOpenAIGPT4OmniMini';
  
        // Create generate text request
        aiplatform.ModelsAPI.createGenerations_Request request = new aiplatform.ModelsAPI.createGenerations_Request();
  
        // Specify model
        request.modelName = modelName;
  
        // Create request body
        aiplatform.ModelsAPI_GenerationRequest requestBody = new aiplatform.ModelsAPI_GenerationRequest();
        request.body = requestBody;
  
        // Add prompt to body
        requestBody.prompt = promptText;
  
        // Make request
        aiplatform.ModelsAPI modelsAPI = new aiplatform.ModelsAPI();
        aiplatform.ModelsAPI.createGenerations_Response response = modelsAPI.createGenerations(
          request
        );
  
        // Extract the generated text from response
        if (response.Code200 != null && response.Code200.generation != null) {
          return response.Code200.generation.generatedText;
        } else {
          return 'No response received from Einstein AI. Please verify Einstein Generative AI is enabled in your org.';
        }
      } catch (aiplatform.ModelsAPI.createGenerations_ResponseException e) {
        System.debug(
          LoggingLevel.ERROR,
          'Models API Response Exception: ' + e.getMessage()
        );
        return 'Error analyzing account: ' +
          e.getMessage() +
          '\\n\\nPlease ensure Einstein AI Models are enabled in Setup → Einstein Setup.';
      } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, 'Models API Error: ' + e.getMessage());
        return 'Unexpected error during AI analysis: ' +
          e.getMessage() +
          '\\n\\nPlease check debug logs for more details.';
      }
    }
  
    /**
     * Wrapper class for opportunity history
     */
    private class OpportunityHistory {
      public List<Opportunity> allOpportunities;
      public Integer totalOpportunities;
      public Integer totalWonOpportunities;
      public Integer totalOpenOpportunities;
      public Decimal totalPipelineValue;
      public Decimal totalACV;
      public Decimal winRate;
      public Decimal averageDealSize;
  
      public OpportunityHistory() {
        this.allOpportunities = new List<Opportunity>();
        this.totalOpportunities = 0;
        this.totalWonOpportunities = 0;
        this.totalOpenOpportunities = 0;
        this.totalPipelineValue = 0;
        this.totalACV = 0;
        this.winRate = 0;
      }
    }
  
    /**
     * Wrapper class for case history
     */
    private class CaseHistory {
      public List<Case> allCases;
      public Integer totalCases;
      public Integer openCases;
      public Integer resolvedCases;
      public Integer totalResolutionDays;
      public Decimal averageResolutionDays;
  
      public CaseHistory() {
        this.allCases = new List<Case>();
        this.totalCases = 0;
        this.openCases = 0;
        this.resolvedCases = 0;
        this.totalResolutionDays = 0;
      }
    }
  
    /**
     * Wrapper class for activity timeline data
     */
    private class ActivityTimeline {
      public List<EmailMessage> emails;
      public List<Task> tasks;
      public List<Event> events;
      public Integer totalEmails;
      public Integer totalTasks;
      public Integer totalEvents;
      public Integer totalActivities;
      public Date mostRecentEmailDate;
      public Date mostRecentActivityDate;
  
      public ActivityTimeline() {
        this.emails = new List<EmailMessage>();
        this.tasks = new List<Task>();
        this.events = new List<Event>();
        this.totalEmails = 0;
        this.totalTasks = 0;
        this.totalEvents = 0;
        this.totalActivities = 0;
      }
    }
  
    /**
     * Wrapper class for invocable method input
     */
    public class AnalysisRequest {
      @InvocableVariable(required=true label='Account ID')
      public String accountId;
    }
  
    /**
     * Wrapper class for invocable method output
     */
    public class AnalysisResult {
      @InvocableVariable(label='Analysis Text')
      public String analysisText;
    }
  }
  
  