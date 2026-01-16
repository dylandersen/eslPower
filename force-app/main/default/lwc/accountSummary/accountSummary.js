import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import getAccountSummary from '@salesforce/apex/AccountSummaryController.getAccountSummary';
import AGENTFORCE_ICON from '@salesforce/resourceUrl/Agentforce_RGB_icon';

export default class AccountSummary extends NavigationMixin(LightningElement) {
    @api recordId;
    
    @track data = null;
    @track isLoading = false;
    @track hasError = false;
    @track errorMessage = '';
    @track currentFlavorText = '';
    
    renderedHtml = '';
    flavorTextInterval;
    
    flavorTexts = [
        'Analyzing opportunities and pipeline...',
        'Reviewing order statuses and fulfillment...',
        'Examining handoff records and engineering workflow...',
        'Processing account data with AI...',
        'Identifying process bottlenecks...',
        'Calculating next steps and recommendations...',
        'Synthesizing insights across all records...',
        'Generating comprehensive summary...'
    ];
    
    get agentforceIconUrl() {
        return AGENTFORCE_ICON;
    }
    
    get showInitialState() {
        return !this.isLoading && !this.hasError && !this.data;
    }
    
    get showResults() {
        return !this.isLoading && !this.hasError && this.data;
    }
    
    get hasOpportunities() {
        return this.data && this.data.opportunities && this.data.opportunities.length > 0;
    }
    
    get hasOrders() {
        return this.data && this.data.orders && this.data.orders.length > 0;
    }
    
    get hasHandoffs() {
        return this.data && this.data.handoffs && this.data.handoffs.length > 0;
    }
    
    get hasActionItems() {
        return this.data && this.data.aiActionItems && this.data.aiActionItems.length > 0;
    }
    
    get hasKeyDates() {
        return this.data && this.data.keyDates && this.data.keyDates.length > 0;
    }
    
    get processedOpportunities() {
        if (!this.data || !this.data.opportunities) return [];
        return this.data.opportunities.map(opp => ({
            ...opp,
            statusClass: this.getStatusClass(opp.statusVariant),
            stageClass: this.getStageClass(opp.stageBadgeClass),
            probabilityClass: this.getProbabilityClass(opp.probability),
            probabilityStyle: `width: ${opp.probability}%`,
            closeDateClass: opp.isOverdue ? 'date-overdue' : (opp.isClosingSoon ? 'date-soon' : ''),
            daysText: this.getDaysText(opp.daysUntilClose, opp.isClosed)
        }));
    }
    
    get processedOrders() {
        if (!this.data || !this.data.orders) return [];
        return this.data.orders.map(ord => ({
            ...ord,
            statusClass: this.getStatusClass(ord.statusVariant),
            effectiveDateClass: ord.isEffectiveSoon ? 'date-soon' : '',
            daysText: this.getOrderDaysText(ord.daysUntilEffective)
        }));
    }
    
    get processedHandoffs() {
        if (!this.data || !this.data.handoffs) return [];
        return this.data.handoffs.map(h => {
            const progressPercent = Math.round((h.statusStep / 7) * 100);
            return {
                ...h,
                statusClass: this.getStatusClass(h.statusVariant),
                peerReviewClass: this.getStatusClass(h.peerReviewVariant),
                progressPercent: progressPercent,
                progressStyle: `width: ${progressPercent}%`,
                hasEngineeringNotes: h.engineeringNotes && h.engineeringNotes.length > 0,
                truncatedNotes: h.engineeringNotes ? (h.engineeringNotes.length > 100 ? h.engineeringNotes.substring(0, 100) + '...' : h.engineeringNotes) : ''
            };
        });
    }
    
    get processedActionItems() {
        if (!this.data || !this.data.aiActionItems) return [];
        return this.data.aiActionItems.map((item, index) => ({
            ...item,
            key: 'action-' + index,
            priorityBadgeClass: this.getPriorityClass(item.priority),
            itemClass: 'action-item ' + item.priority + '-priority'
        }));
    }
    
    get processedKeyDates() {
        if (!this.data || !this.data.keyDates) return [];
        return this.data.keyDates.slice(0, 5).map((kd, index) => ({
            ...kd,
            key: 'date-' + index,
            dateClass: this.getDateClass(kd.variant),
            iconName: kd.recordType === 'Opportunity' ? 'standard:opportunity' : 'standard:orders'
        }));
    }
    
    getStatusClass(variant) {
        const classes = {
            'success': 'badge-success',
            'error': 'badge-error',
            'warning': 'badge-warning',
            'info': 'badge-info',
            'default': 'badge-default'
        };
        return classes[variant] || 'badge-default';
    }
    
    getStageClass(badgeClass) {
        const classes = {
            'success': 'stage-success',
            'error': 'stage-error',
            'warning': 'stage-warning',
            'info': 'stage-info',
            'default': 'stage-default'
        };
        return classes[badgeClass] || 'stage-default';
    }
    
    getProbabilityClass(probability) {
        if (probability >= 75) return 'prob-high';
        if (probability >= 50) return 'prob-medium';
        return 'prob-low';
    }
    
    getPriorityClass(priority) {
        const classes = {
            'high': 'priority-high',
            'medium': 'priority-medium',
            'low': 'priority-low'
        };
        return classes[priority] || 'priority-low';
    }
    
    getDateClass(variant) {
        const classes = {
            'error': 'date-overdue',
            'warning': 'date-soon',
            'default': ''
        };
        return classes[variant] || '';
    }
    
    getDaysText(days, isClosed) {
        if (isClosed) return '';
        if (days < 0) return Math.abs(days) + ' days overdue';
        if (days === 0) return 'Today';
        if (days === 1) return 'Tomorrow';
        if (days <= 7) return days + ' days';
        if (days <= 30) return Math.round(days / 7) + ' weeks';
        return Math.round(days / 30) + ' months';
    }
    
    getOrderDaysText(days) {
        if (days === undefined || days === null) return '';
        if (days < 0) return Math.abs(days) + ' days ago';
        if (days === 0) return 'Today';
        if (days === 1) return 'Tomorrow';
        if (days <= 14) return 'In ' + days + ' days';
        return '';
    }
    
    startFlavorTextRotation() {
        this.currentFlavorText = this.flavorTexts[0];
        
        if (this.flavorTextInterval) {
            clearInterval(this.flavorTextInterval);
        }
        
        this.flavorTextInterval = setInterval(() => {
            const randomIndex = Math.floor(Math.random() * this.flavorTexts.length);
            this.currentFlavorText = this.flavorTexts[randomIndex];
        }, 2000 + Math.random() * 3000);
    }
    
    stopFlavorTextRotation() {
        if (this.flavorTextInterval) {
            clearInterval(this.flavorTextInterval);
            this.flavorTextInterval = null;
        }
        this.currentFlavorText = '';
    }
    
    async handleSummarize() {
        this.isLoading = true;
        this.hasError = false;
        this.data = null;
        this.errorMessage = '';
        
        this.startFlavorTextRotation();
        
        try {
            const result = await getAccountSummary({ accountId: this.recordId });
            
            this.stopFlavorTextRotation();
            
            if (result.success) {
                this.data = result;
                this.showSuccessToast('Summary Generated', 'Account summary has been generated successfully.');
            } else {
                this.hasError = true;
                this.errorMessage = result.errorMessage || 'An unknown error occurred.';
                this.showErrorToast('Error', this.errorMessage);
            }
        } catch (error) {
            this.stopFlavorTextRotation();
            this.hasError = true;
            this.errorMessage = error.body?.message || error.message || 'An unexpected error occurred.';
            this.showErrorToast('Error', this.errorMessage);
            console.error('Error:', error);
        } finally {
            this.isLoading = false;
        }
    }
    
    handleRetry() {
        this.handleSummarize();
    }
    
    handleRefresh() {
        this.data = null;
        this.stopFlavorTextRotation();
        this.handleSummarize();
    }
    
    handleCompose() {
        if (!this.data) {
            this.showErrorToast('No Summary Available', 'Please generate a summary first before composing an email.');
            return;
        }
        
        // Use pre-generated email body and subject from Apex (generated during summarize)
        let subject = this.data.emailSubject || `Account Summary: ${this.data.accountName}`;
        let htmlBody = this.data.emailBody;
        
        // Fallback: If emailBody is missing, generate it client-side
        if (!htmlBody || htmlBody.trim().length === 0) {
            console.warn('Email body missing from Apex, generating client-side fallback');
            htmlBody = this.generateEmailBodyFallback();
        }
        
        // Ensure we have valid content
        if (!htmlBody || htmlBody.trim().length === 0) {
            this.showErrorToast('Email Content Error', 'Unable to generate email content. Please try refreshing the summary.');
            return;
        }
        
        // Debug logging
        console.log('Composing email:', {
            subject: subject,
            bodyLength: htmlBody?.length,
            bodyPreview: htmlBody?.substring(0, 200)
        });
        
        // Encode the default field values - use HtmlBody (not HTMLBody) for Salesforce email composer
        const defaultValues = encodeDefaultFieldValues({
            Subject: subject,
            HtmlBody: htmlBody  // Changed from HTMLBody to HtmlBody - Salesforce expects this exact casing
        });
        
        // Use Global.SendEmail which opens in a panel/modal (not full-screen)
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: {
                apiName: 'Global.SendEmail'
            },
            state: {
                recordId: this.recordId,
                defaultFieldValues: defaultValues
            }
        });
    }
    
    generateEmailBodyFallback() {
        if (!this.data) return '';
        
        let htmlBody = '<div style="font-family: Arial, sans-serif; line-height: 1.6;">';
        htmlBody += `<h2 style="color: #0176d3;">Account Summary: ${this.data.accountName || 'Account'}</h2>`;
        
        if (this.data.accountIndustry) {
            htmlBody += `<p><strong>Industry:</strong> ${this.data.accountIndustry}</p>`;
        }
        
        // Metrics Summary
        htmlBody += '<h3 style="color: #0176d3; margin-top: 20px;">Key Metrics</h3>';
        htmlBody += '<ul>';
        htmlBody += `<li><strong>Open Opportunities:</strong> ${this.data.openOpportunities || 0}</li>`;
        htmlBody += `<li><strong>Pipeline Value:</strong> ${this.data.formattedPipelineValue || '$0'}</li>`;
        htmlBody += `<li><strong>Active Orders:</strong> ${this.data.totalOrders || 0}</li>`;
        htmlBody += `<li><strong>Handoffs:</strong> ${this.data.totalHandoffs || 0}</li>`;
        htmlBody += '</ul>';
        
        // AI Summary
        if (this.data.aiSummary) {
            htmlBody += '<h3 style="color: #0176d3; margin-top: 20px;">At a Glance</h3>';
            htmlBody += `<p>${this.data.aiSummary}</p>`;
        }
        
        htmlBody += '<hr style="margin-top: 30px; border: none; border-top: 1px solid #ddd;">';
        htmlBody += '<p style="color: #706e6b; font-size: 12px;">Generated by Agentforce Account Summary</p>';
        htmlBody += '</div>';
        
        return htmlBody;
    }
    
    navigateToRecord(event) {
        const recordId = event.currentTarget.dataset.recordId;
        const objectType = event.currentTarget.dataset.objectType;
        
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: objectType,
                    actionName: 'view'
                }
            });
        }
    }
    
    disconnectedCallback() {
        this.stopFlavorTextRotation();
    }
    
    showSuccessToast(title, message) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: 'success',
            mode: 'dismissable'
        }));
    }
    
    showErrorToast(title, message) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: 'error',
            mode: 'sticky'
        }));
    }
}
