public with sharing class AccountSummaryController {
    /**
     * Main entry point to get account summary with structured data
     * @param accountId The Account ID to summarize
     * @return SummaryResult containing structured data and AI insights
     */
    @AuraEnabled(cacheable=false)
    public static SummaryResult getAccountSummary(String accountId) {
        SummaryResult result = new SummaryResult();
        
        try {
            if (String.isBlank(accountId)) {
                result.success = false;
                result.errorMessage = 'Account ID is required.';
                return result;
            }
            
            // Query account data
            List<Account> accountList = queryAccountData(accountId);
            
            if (accountList.isEmpty()) {
                result.success = false;
                result.errorMessage = 'Account not found with ID: ' + accountId;
                return result;
            }
            
            Account account = accountList[0];
            result.accountName = account.Name;
            result.accountIndustry = account.Industry;
            
            // Query and process opportunities
            List<Opportunity> opportunities = queryOpportunities(accountId);
            processOpportunities(opportunities, result);
            
            // Query and process orders
            List<Order> orders = queryOrders(accountId);
            processOrders(orders, result);
            
            // Query and process handoffs
            List<Handoff__c> handoffs = queryHandoffs(accountId);
            processHandoffs(handoffs, result);
            
            // Build key dates
            buildKeyDates(result);
            
            // Get AI insights (summary + action items only)
            String aiPrompt = buildAIPrompt(account, opportunities, orders, handoffs, result);
            AIInsights insights = getAIInsights(aiPrompt);
            result.aiSummary = insights.summary;
            result.aiActionItems = insights.actionItems;
            
            // Generate email body and subject
            result.emailSubject = 'Account Summary: ' + account.Name;
            result.emailBody = generateEmailBody(account, result, opportunities, orders, handoffs);
            
            result.success = true;
            
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = 'Error generating summary: ' + e.getMessage();
            System.debug(LoggingLevel.ERROR, 'AccountSummaryController Error: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack Trace: ' + e.getStackTraceString());
        }
        
        return result;
    }
    
    private static List<Account> queryAccountData(String accountId) {
        return [
            SELECT Id, Name, Industry, Type, AnnualRevenue, NumberOfEmployees, CreatedDate
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
    }
    
    private static List<Opportunity> queryOpportunities(String accountId) {
        return [
            SELECT Id, Name, StageName, Amount, CloseDate, IsWon, IsClosed, Probability, 
                   CreatedDate, OwnerId, Owner.Name, Type
            FROM Opportunity
            WHERE AccountId = :accountId
            ORDER BY CloseDate ASC
            LIMIT 100
        ];
    }
    
    private static List<Order> queryOrders(String accountId) {
        return [
            SELECT Id, OrderNumber, Status, TotalAmount, EffectiveDate, OpportunityId, CreatedDate
            FROM Order
            WHERE AccountId = :accountId
            ORDER BY EffectiveDate DESC
            LIMIT 100
        ];
    }
    
    private static List<Handoff__c> queryHandoffs(String accountId) {
        return [
            SELECT Id, Name, Order__c, Order__r.OrderNumber, Status__c, Product_Lines__c,
                   Application__c, Customer_Intent__c, Sales_Notes__c, Engineering_Notes__c,
                   Peer_Review_Status__c, Peer_Review_Notes__c, CreatedDate
            FROM Handoff__c
            WHERE Order__r.AccountId = :accountId
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];
    }
    
    private static void processOpportunities(List<Opportunity> opportunities, SummaryResult result) {
        result.opportunities = new List<OpportunityData>();
        result.totalOpportunities = opportunities.size();
        result.openOpportunities = 0;
        result.wonOpportunities = 0;
        result.lostOpportunities = 0;
        result.pipelineValue = 0;
        result.wonValue = 0;
        
        for (Opportunity opp : opportunities) {
            OpportunityData oppData = new OpportunityData();
            oppData.id = opp.Id;
            oppData.name = opp.Name;
            oppData.stageName = opp.StageName;
            oppData.amount = opp.Amount != null ? opp.Amount : 0;
            oppData.formattedAmount = opp.Amount != null ? '$' + opp.Amount.format() : '$0';
            oppData.closeDate = opp.CloseDate;
            oppData.formattedCloseDate = opp.CloseDate != null ? formatDate(opp.CloseDate) : 'Not set';
            oppData.probability = opp.Probability != null ? opp.Probability.intValue() : 0;
            oppData.ownerName = opp.Owner != null ? opp.Owner.Name : 'Unassigned';
            oppData.isWon = opp.IsWon;
            oppData.isClosed = opp.IsClosed;
            
            // Calculate days until close
            if (opp.CloseDate != null && !opp.IsClosed) {
                oppData.daysUntilClose = Date.today().daysBetween(opp.CloseDate);
            } else {
                oppData.daysUntilClose = 0;
            }
            
            // Determine status and styling
            if (opp.IsWon) {
                oppData.status = 'Won';
                oppData.statusVariant = 'success';
                result.wonOpportunities++;
                if (opp.Amount != null) result.wonValue += opp.Amount;
            } else if (opp.IsClosed) {
                oppData.status = 'Lost';
                oppData.statusVariant = 'error';
                result.lostOpportunities++;
            } else {
                oppData.status = 'Open';
                oppData.statusVariant = 'warning';
                result.openOpportunities++;
                if (opp.Amount != null) result.pipelineValue += opp.Amount;
                
                // Check if closing soon
                if (oppData.daysUntilClose <= 7 && oppData.daysUntilClose >= 0) {
                    oppData.isClosingSoon = true;
                }
                // Check if overdue
                if (oppData.daysUntilClose < 0) {
                    oppData.isOverdue = true;
                    oppData.statusVariant = 'error';
                }
            }
            
            // Stage badge color
            oppData.stageBadgeClass = getStageBadgeClass(opp.StageName);
            
            result.opportunities.add(oppData);
        }
        
        result.formattedPipelineValue = '$' + result.pipelineValue.format();
        result.formattedWonValue = '$' + result.wonValue.format();
    }
    
    private static void processOrders(List<Order> orders, SummaryResult result) {
        result.orders = new List<OrderData>();
        result.totalOrders = orders.size();
        result.totalOrderValue = 0;
        result.draftOrders = 0;
        result.activatedOrders = 0;
        
        for (Order ord : orders) {
            OrderData orderData = new OrderData();
            orderData.id = ord.Id;
            orderData.orderNumber = ord.OrderNumber;
            orderData.status = ord.Status;
            orderData.totalAmount = ord.TotalAmount != null ? ord.TotalAmount : 0;
            orderData.formattedAmount = ord.TotalAmount != null ? '$' + ord.TotalAmount.format() : '$0';
            orderData.effectiveDate = ord.EffectiveDate;
            orderData.formattedEffectiveDate = ord.EffectiveDate != null ? formatDate(ord.EffectiveDate) : 'Not set';
            
            if (ord.TotalAmount != null) result.totalOrderValue += ord.TotalAmount;
            
            // Status styling
            if (ord.Status == 'Draft') {
                orderData.statusVariant = 'warning';
                orderData.isDraft = true;
                result.draftOrders++;
            } else if (ord.Status == 'Activated') {
                orderData.statusVariant = 'success';
                result.activatedOrders++;
            } else {
                orderData.statusVariant = 'default';
            }
            
            // Days until effective
            if (ord.EffectiveDate != null) {
                orderData.daysUntilEffective = Date.today().daysBetween(ord.EffectiveDate);
                if (orderData.daysUntilEffective <= 14 && orderData.daysUntilEffective >= 0) {
                    orderData.isEffectiveSoon = true;
                }
            }
            
            result.orders.add(orderData);
        }
        
        result.formattedOrderValue = '$' + result.totalOrderValue.format();
    }
    
    private static void processHandoffs(List<Handoff__c> handoffs, SummaryResult result) {
        result.handoffs = new List<HandoffData>();
        result.totalHandoffs = handoffs.size();
        result.pendingHandoffs = 0;
        result.completedHandoffs = 0;
        
        for (Handoff__c handoff : handoffs) {
            HandoffData hData = new HandoffData();
            hData.id = handoff.Id;
            hData.name = handoff.Name;
            hData.status = handoff.Status__c;
            hData.productLines = handoff.Product_Lines__c;
            hData.application = handoff.Application__c;
            hData.orderNumber = handoff.Order__r != null ? handoff.Order__r.OrderNumber : '';
            hData.peerReviewStatus = handoff.Peer_Review_Status__c;
            hData.customerIntent = handoff.Customer_Intent__c;
            hData.engineeringNotes = handoff.Engineering_Notes__c;
            
            // Status styling
            String status = handoff.Status__c != null ? handoff.Status__c : '';
            if (status == 'Complete' || status == 'Ready to Buy') {
                hData.statusVariant = 'success';
                result.completedHandoffs++;
            } else if (status == 'Pending Review' || status == 'In Review') {
                hData.statusVariant = 'warning';
                result.pendingHandoffs++;
            } else if (status == 'Peer Review' || status == 'BOM Created' || status == 'Drawings Created') {
                hData.statusVariant = 'info';
                result.pendingHandoffs++;
            } else {
                hData.statusVariant = 'default';
                result.pendingHandoffs++;
            }
            
            // Peer review badge
            if (handoff.Peer_Review_Status__c == 'Pass') {
                hData.peerReviewVariant = 'success';
            } else if (handoff.Peer_Review_Status__c == 'Fail') {
                hData.peerReviewVariant = 'error';
            } else {
                hData.peerReviewVariant = 'warning';
            }
            
            // Get status step for progress indicator
            hData.statusStep = getHandoffStatusStep(status);
            
            result.handoffs.add(hData);
        }
    }
    
    private static void buildKeyDates(SummaryResult result) {
        result.keyDates = new List<KeyDateData>();
        
        // Add opportunity close dates
        for (OpportunityData opp : result.opportunities) {
            if (!opp.isClosed && opp.closeDate != null) {
                KeyDateData kd = new KeyDateData();
                kd.dateValue = opp.closeDate;
                kd.formattedDate = opp.formattedCloseDate;
                kd.description = opp.name + ' - Close Date';
                kd.recordType = 'Opportunity';
                kd.variant = opp.daysUntilClose < 0 ? 'error' : (opp.daysUntilClose <= 7 ? 'warning' : 'default');
                kd.daysAway = opp.daysUntilClose;
                result.keyDates.add(kd);
            }
        }
        
        // Add order effective dates
        for (OrderData ord : result.orders) {
            if (ord.effectiveDate != null) {
                KeyDateData kd = new KeyDateData();
                kd.dateValue = ord.effectiveDate;
                kd.formattedDate = ord.formattedEffectiveDate;
                kd.description = 'Order #' + ord.orderNumber + ' - Effective Date';
                kd.recordType = 'Order';
                kd.variant = ord.daysUntilEffective <= 14 ? 'warning' : 'default';
                kd.daysAway = ord.daysUntilEffective;
                result.keyDates.add(kd);
            }
        }
        
        // Sort by date
        result.keyDates.sort();
    }
    
    private static String buildAIPrompt(Account account, List<Opportunity> opportunities, 
                                        List<Order> orders, List<Handoff__c> handoffs, SummaryResult result) {
        List<String> promptParts = new List<String>();
        
        promptParts.add('You are an expert Account Manager. Analyze this account data and provide insights.');
        promptParts.add('Today is ' + Date.today().format() + '.');
        promptParts.add('');
        promptParts.add('ACCOUNT: ' + account.Name);
        promptParts.add('Industry: ' + (account.Industry != null ? account.Industry : 'N/A'));
        promptParts.add('');
        promptParts.add('METRICS:');
        promptParts.add('- Open Opportunities: ' + result.openOpportunities);
        promptParts.add('- Pipeline Value: ' + result.formattedPipelineValue);
        promptParts.add('- Total Orders: ' + result.totalOrders + ' (Draft: ' + result.draftOrders + ')');
        promptParts.add('- Handoffs: ' + result.totalHandoffs + ' (Pending: ' + result.pendingHandoffs + ')');
        promptParts.add('');
        
        // Opportunity details
        if (!opportunities.isEmpty()) {
            promptParts.add('OPPORTUNITIES:');
            for (Opportunity opp : opportunities) {
                String status = opp.IsWon ? 'Won' : (opp.IsClosed ? 'Lost' : 'Open');
                promptParts.add('- ' + opp.Name + ': ' + status + ', $' + 
                    (opp.Amount != null ? opp.Amount.format() : '0') + 
                    ', Close: ' + (opp.CloseDate != null ? opp.CloseDate.format() : 'N/A') +
                    ', Stage: ' + opp.StageName +
                    ', Probability: ' + (opp.Probability != null ? opp.Probability + '%' : 'N/A'));
            }
            promptParts.add('');
        }
        
        // Order details
        if (!orders.isEmpty()) {
            promptParts.add('ORDERS:');
            for (Order ord : orders) {
                promptParts.add('- Order #' + ord.OrderNumber + ': ' + ord.Status + 
                    ', $' + (ord.TotalAmount != null ? ord.TotalAmount.format() : '0') +
                    ', Effective: ' + (ord.EffectiveDate != null ? ord.EffectiveDate.format() : 'N/A'));
            }
            promptParts.add('');
        }
        
        // Handoff details
        if (!handoffs.isEmpty()) {
            promptParts.add('HANDOFFS:');
            for (Handoff__c h : handoffs) {
                promptParts.add('- ' + h.Name + ': Status=' + h.Status__c + 
                    ', Products=' + h.Product_Lines__c +
                    ', PeerReview=' + h.Peer_Review_Status__c);
                if (String.isNotBlank(h.Engineering_Notes__c)) {
                    promptParts.add('  Engineering Notes: ' + h.Engineering_Notes__c);
                }
            }
            promptParts.add('');
        }
        
        promptParts.add('');
        promptParts.add('RESPOND IN EXACTLY THIS JSON FORMAT (no markdown, no code blocks):');
        promptParts.add('{');
        promptParts.add('  "summary": "2-3 sentence executive summary highlighting critical status and immediate needs",');
        promptParts.add('  "actionItems": [');
        promptParts.add('    {');
        promptParts.add('      "title": "Short action title",');
        promptParts.add('      "description": "One sentence description",');
        promptParts.add('      "timeline": "X days/weeks",');
        promptParts.add('      "priority": "high|medium|low"');
        promptParts.add('    }');
        promptParts.add('  ]');
        promptParts.add('}');
        promptParts.add('');
        promptParts.add('Provide 2-4 actionable items based on the data. Be specific and concise.');
        
        return String.join(promptParts, '\n');
    }
    
    private static AIInsights getAIInsights(String promptText) {
        AIInsights insights = new AIInsights();
        insights.actionItems = new List<ActionItemData>();
        
        try {
            String modelName = 'sfdc_ai__DefaultOpenAIGPT4OmniMini';
            
            aiplatform.ModelsAPI.createGenerations_Request request = new aiplatform.ModelsAPI.createGenerations_Request();
            request.modelName = modelName;
            
            aiplatform.ModelsAPI_GenerationRequest requestBody = new aiplatform.ModelsAPI_GenerationRequest();
            request.body = requestBody;
            requestBody.prompt = promptText;
            
            aiplatform.ModelsAPI modelsAPI = new aiplatform.ModelsAPI();
            aiplatform.ModelsAPI.createGenerations_Response response = modelsAPI.createGenerations(request);
            
            if (response.Code200 != null && response.Code200.generation != null) {
                String jsonResponse = response.Code200.generation.generatedText;
                
                // Clean up response - remove markdown code blocks if present
                jsonResponse = jsonResponse.trim();
                if (jsonResponse.startsWith('```')) {
                    jsonResponse = jsonResponse.substringAfter('\n');
                    jsonResponse = jsonResponse.substringBeforeLast('```');
                }
                jsonResponse = jsonResponse.trim();
                
                // Parse JSON response
                Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
                
                insights.summary = (String) parsed.get('summary');
                
                List<Object> actions = (List<Object>) parsed.get('actionItems');
                if (actions != null) {
                    for (Object action : actions) {
                        Map<String, Object> actionMap = (Map<String, Object>) action;
                        ActionItemData item = new ActionItemData();
                        item.title = (String) actionMap.get('title');
                        item.description = (String) actionMap.get('description');
                        item.timeline = (String) actionMap.get('timeline');
                        item.priority = (String) actionMap.get('priority');
                        
                        // Set priority variant
                        if (item.priority == 'high') {
                            item.priorityVariant = 'error';
                            item.priorityIcon = 'utility:warning';
                        } else if (item.priority == 'medium') {
                            item.priorityVariant = 'warning';
                            item.priorityIcon = 'utility:info';
                        } else {
                            item.priorityVariant = 'success';
                            item.priorityIcon = 'utility:check';
                        }
                        
                        insights.actionItems.add(item);
                    }
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'AI Error: ' + e.getMessage());
            insights.summary = 'Unable to generate AI insights. Please review the data manually.';
        }
        
        // Provide defaults if empty
        if (String.isBlank(insights.summary)) {
            insights.summary = 'Review the opportunities, orders, and handoffs below for current status.';
        }
        
        return insights;
    }
    
    private static String generateEmailBody(Account account, SummaryResult result, List<Opportunity> opportunities, List<Order> orders, List<Handoff__c> handoffs) {
        String htmlBody = '<div style="font-family: Arial, sans-serif; line-height: 1.6;">';
        htmlBody += '<h2 style="color: #0176d3;">Account Summary: ' + String.escapeSingleQuotes(account.Name) + '</h2>';
        
        if (String.isNotBlank(account.Industry)) {
            htmlBody += '<p><strong>Industry:</strong> ' + String.escapeSingleQuotes(account.Industry) + '</p>';
        }
        
        // Metrics Summary
        htmlBody += '<h3 style="color: #0176d3; margin-top: 20px;">Key Metrics</h3>';
        htmlBody += '<ul>';
        htmlBody += '<li><strong>Open Opportunities:</strong> ' + result.openOpportunities + '</li>';
        htmlBody += '<li><strong>Pipeline Value:</strong> ' + result.formattedPipelineValue + '</li>';
        htmlBody += '<li><strong>Active Orders:</strong> ' + result.totalOrders + '</li>';
        htmlBody += '<li><strong>Handoffs:</strong> ' + result.totalHandoffs + '</li>';
        htmlBody += '</ul>';
        
        // AI Summary
        if (String.isNotBlank(result.aiSummary)) {
            htmlBody += '<h3 style="color: #0176d3; margin-top: 20px;">At a Glance</h3>';
            htmlBody += '<p>' + String.escapeSingleQuotes(result.aiSummary) + '</p>';
        }
        
        // Opportunities
        if (opportunities != null && !opportunities.isEmpty()) {
            htmlBody += '<h3 style="color: #0176d3; margin-top: 20px;">Opportunities</h3>';
            htmlBody += '<ul>';
            for (Opportunity opp : opportunities) {
                String oppName = String.escapeSingleQuotes(opp.Name);
                String stageName = String.escapeSingleQuotes(opp.StageName);
                String amount = formatCurrency(opp.Amount);
                String closeDate = formatDate(opp.CloseDate);
                htmlBody += '<li><strong>' + oppName + '</strong> - ' + amount + ' (' + stageName + ') - Close Date: ' + closeDate + '</li>';
            }
            htmlBody += '</ul>';
        }
        
        // Orders
        if (orders != null && !orders.isEmpty()) {
            htmlBody += '<h3 style="color: #0176d3; margin-top: 20px;">Orders</h3>';
            htmlBody += '<ul>';
            for (Order ord : orders) {
                String orderNum = ord.OrderNumber != null ? String.valueOf(ord.OrderNumber) : 'N/A';
                String status = String.escapeSingleQuotes(ord.Status);
                String amount = formatCurrency(ord.TotalAmount);
                String effectiveDate = formatDate(ord.EffectiveDate);
                htmlBody += '<li><strong>Order #' + orderNum + '</strong> - ' + amount + ' (' + status + ') - Effective Date: ' + effectiveDate + '</li>';
            }
            htmlBody += '</ul>';
        }
        
        // Handoffs
        if (handoffs != null && !handoffs.isEmpty()) {
            htmlBody += '<h3 style="color: #0176d3; margin-top: 20px;">Handoffs</h3>';
            htmlBody += '<ul>';
            for (Handoff__c h : handoffs) {
                String handoffName = String.escapeSingleQuotes(h.Name);
                String status = String.escapeSingleQuotes(h.Status__c);
                Integer progressPercent = Math.round((getHandoffStatusStep(h.Status__c) / 7.0) * 100);
                htmlBody += '<li><strong>' + handoffName + '</strong> - ' + status + ' (' + progressPercent + '% complete)';
                if (h.Order__r != null && h.Order__r.OrderNumber != null) {
                    htmlBody += ' - Order #' + String.valueOf(h.Order__r.OrderNumber);
                }
                htmlBody += '</li>';
            }
            htmlBody += '</ul>';
        }
        
        // Action Items
        if (result.aiActionItems != null && !result.aiActionItems.isEmpty()) {
            htmlBody += '<h3 style="color: #0176d3; margin-top: 20px;">Recommended Actions</h3>';
            htmlBody += '<ul>';
            for (ActionItemData action : result.aiActionItems) {
                String title = String.escapeSingleQuotes(action.title);
                String description = String.escapeSingleQuotes(action.description);
                String timeline = String.escapeSingleQuotes(action.timeline);
                String priority = action.priority != null ? action.priority.toUpperCase() : 'MEDIUM';
                htmlBody += '<li><strong>[' + priority + ']</strong> ' + title + ' - ' + description + ' (' + timeline + ')</li>';
            }
            htmlBody += '</ul>';
        }
        
        // Key Dates
        if (result.keyDates != null && !result.keyDates.isEmpty()) {
            htmlBody += '<h3 style="color: #0176d3; margin-top: 20px;">Key Dates</h3>';
            htmlBody += '<ul>';
            Integer count = 0;
            for (KeyDateData kd : result.keyDates) {
                if (count >= 5) break;
                String formattedDate = String.escapeSingleQuotes(kd.formattedDate);
                String description = String.escapeSingleQuotes(kd.description);
                htmlBody += '<li><strong>' + formattedDate + '</strong> - ' + description + '</li>';
                count++;
            }
            htmlBody += '</ul>';
        }
        
        htmlBody += '<hr style="margin-top: 30px; border: none; border-top: 1px solid #ddd;">';
        htmlBody += '<p style="color: #706e6b; font-size: 12px;">Generated by Agentforce Account Summary</p>';
        htmlBody += '</div>';
        
        return htmlBody;
    }
    
    private static String formatCurrency(Decimal amount) {
        if (amount == null) return '$0';
        return '$' + String.valueOf(amount.format());
    }
    
    private static String formatDate(Date d) {
        if (d == null) return '';
        Datetime dt = Datetime.newInstance(d.year(), d.month(), d.day());
        return dt.format('MMM d, yyyy');
    }
    
    private static String getStageBadgeClass(String stageName) {
        if (stageName == null) return 'default';
        String stage = stageName.toLowerCase();
        if (stage.contains('closed won') || stage.contains('won')) return 'success';
        if (stage.contains('closed lost') || stage.contains('lost')) return 'error';
        if (stage.contains('negotiation') || stage.contains('proposal')) return 'warning';
        if (stage.contains('qualification') || stage.contains('discovery')) return 'info';
        return 'default';
    }
    
    private static Integer getHandoffStatusStep(String status) {
        if (status == null) return 1;
        if (status == 'Pending Review') return 1;
        if (status == 'In Review') return 2;
        if (status == 'BOM Created') return 3;
        if (status == 'Drawings Created') return 4;
        if (status == 'Peer Review') return 5;
        if (status == 'Ready to Buy') return 6;
        if (status == 'Complete') return 7;
        return 1;
    }
    
    // ========== Data Classes ==========
    
    public class SummaryResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
        
        // Account
        @AuraEnabled public String accountName;
        @AuraEnabled public String accountIndustry;
        
        // Opportunity Metrics
        @AuraEnabled public Integer totalOpportunities;
        @AuraEnabled public Integer openOpportunities;
        @AuraEnabled public Integer wonOpportunities;
        @AuraEnabled public Integer lostOpportunities;
        @AuraEnabled public Decimal pipelineValue;
        @AuraEnabled public Decimal wonValue;
        @AuraEnabled public String formattedPipelineValue;
        @AuraEnabled public String formattedWonValue;
        
        // Order Metrics
        @AuraEnabled public Integer totalOrders;
        @AuraEnabled public Integer draftOrders;
        @AuraEnabled public Integer activatedOrders;
        @AuraEnabled public Decimal totalOrderValue;
        @AuraEnabled public String formattedOrderValue;
        
        // Handoff Metrics
        @AuraEnabled public Integer totalHandoffs;
        @AuraEnabled public Integer pendingHandoffs;
        @AuraEnabled public Integer completedHandoffs;
        
        // Data Lists
        @AuraEnabled public List<OpportunityData> opportunities;
        @AuraEnabled public List<OrderData> orders;
        @AuraEnabled public List<HandoffData> handoffs;
        @AuraEnabled public List<KeyDateData> keyDates;
        
        // AI Insights
        @AuraEnabled public String aiSummary;
        @AuraEnabled public List<ActionItemData> aiActionItems;
        
        // Pre-generated Email Content
        @AuraEnabled public String emailSubject;
        @AuraEnabled public String emailBody;
        
        public SummaryResult() {
            this.success = false;
            this.pipelineValue = 0;
            this.wonValue = 0;
            this.totalOrderValue = 0;
        }
    }
    
    public class OpportunityData {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String stageName;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String formattedAmount;
        @AuraEnabled public Date closeDate;
        @AuraEnabled public String formattedCloseDate;
        @AuraEnabled public Integer probability;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String status;
        @AuraEnabled public String statusVariant;
        @AuraEnabled public String stageBadgeClass;
        @AuraEnabled public Boolean isWon;
        @AuraEnabled public Boolean isClosed;
        @AuraEnabled public Integer daysUntilClose;
        @AuraEnabled public Boolean isClosingSoon;
        @AuraEnabled public Boolean isOverdue;
    }
    
    public class OrderData {
        @AuraEnabled public String id;
        @AuraEnabled public String orderNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String statusVariant;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public String formattedAmount;
        @AuraEnabled public Date effectiveDate;
        @AuraEnabled public String formattedEffectiveDate;
        @AuraEnabled public Integer daysUntilEffective;
        @AuraEnabled public Boolean isDraft;
        @AuraEnabled public Boolean isEffectiveSoon;
    }
    
    public class HandoffData {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String statusVariant;
        @AuraEnabled public String productLines;
        @AuraEnabled public String application;
        @AuraEnabled public String orderNumber;
        @AuraEnabled public String peerReviewStatus;
        @AuraEnabled public String peerReviewVariant;
        @AuraEnabled public String customerIntent;
        @AuraEnabled public String engineeringNotes;
        @AuraEnabled public Integer statusStep;
    }
    
    public class KeyDateData implements Comparable {
        @AuraEnabled public Date dateValue;
        @AuraEnabled public String formattedDate;
        @AuraEnabled public String description;
        @AuraEnabled public String recordType;
        @AuraEnabled public String variant;
        @AuraEnabled public Integer daysAway;
        
        public Integer compareTo(Object compareTo) {
            KeyDateData other = (KeyDateData) compareTo;
            if (this.dateValue == null) return 1;
            if (other.dateValue == null) return -1;
            if (this.dateValue < other.dateValue) return -1;
            if (this.dateValue > other.dateValue) return 1;
            return 0;
        }
    }
    
    public class ActionItemData {
        @AuraEnabled public String title;
        @AuraEnabled public String description;
        @AuraEnabled public String timeline;
        @AuraEnabled public String priority;
        @AuraEnabled public String priorityVariant;
        @AuraEnabled public String priorityIcon;
    }
    
    private class AIInsights {
        public String summary;
        public List<ActionItemData> actionItems;
    }
}
