import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

// Handoff fields
import HANDOFF_NAME from '@salesforce/schema/Handoff__c.Name';
import HANDOFF_ORDER from '@salesforce/schema/Handoff__c.Order__c';
import HANDOFF_PRODUCT_LINES from '@salesforce/schema/Handoff__c.Product_Lines__c';
import HANDOFF_APPLICATION from '@salesforce/schema/Handoff__c.Application__c';
import HANDOFF_VOLTAGE from '@salesforce/schema/Handoff__c.Voltage__c';
import HANDOFF_AMPERAGE from '@salesforce/schema/Handoff__c.Amperage__c';
import HANDOFF_ENCLOSURE from '@salesforce/schema/Handoff__c.Enclosure__c';
import HANDOFF_CONNECTOR_TYPE from '@salesforce/schema/Handoff__c.Connector_Type__c';
import HANDOFF_SITE_CONDITIONS from '@salesforce/schema/Handoff__c.Site_Conditions__c';
import HANDOFF_CUSTOMER_INTENT from '@salesforce/schema/Handoff__c.Customer_Intent__c';
import HANDOFF_SALES_NOTES from '@salesforce/schema/Handoff__c.Sales_Notes__c';
import HANDOFF_STATUS from '@salesforce/schema/Handoff__c.Status__c';
import HANDOFF_ENGINEERING_NOTES from '@salesforce/schema/Handoff__c.Engineering_Notes__c';
import HANDOFF_PEER_REVIEW_STATUS from '@salesforce/schema/Handoff__c.Peer_Review_Status__c';
import HANDOFF_PEER_REVIEW_NOTES from '@salesforce/schema/Handoff__c.Peer_Review_Notes__c';

// Order fields
import ORDER_NUMBER from '@salesforce/schema/Order.OrderNumber';
import ORDER_ACCOUNT from '@salesforce/schema/Order.AccountId';
import ORDER_CONTACT from '@salesforce/schema/Order.Contact__c';

// Account fields
import ACCOUNT_NAME from '@salesforce/schema/Account.Name';
import ACCOUNT_INDUSTRY from '@salesforce/schema/Account.Industry';

// Contact fields
import CONTACT_NAME from '@salesforce/schema/Contact.Name';
import CONTACT_TITLE from '@salesforce/schema/Contact.Title';

const HANDOFF_FIELDS = [
    HANDOFF_NAME,
    HANDOFF_ORDER,
    HANDOFF_PRODUCT_LINES,
    HANDOFF_APPLICATION,
    HANDOFF_VOLTAGE,
    HANDOFF_AMPERAGE,
    HANDOFF_ENCLOSURE,
    HANDOFF_CONNECTOR_TYPE,
    HANDOFF_SITE_CONDITIONS,
    HANDOFF_CUSTOMER_INTENT,
    HANDOFF_SALES_NOTES,
    HANDOFF_STATUS,
    HANDOFF_ENGINEERING_NOTES,
    HANDOFF_PEER_REVIEW_STATUS,
    HANDOFF_PEER_REVIEW_NOTES
];

const ORDER_FIELDS = [ORDER_NUMBER, ORDER_ACCOUNT, ORDER_CONTACT];

export default class HandoffVisualization extends NavigationMixin(LightningElement) {
    @api recordId;

    handoffData;
    orderId;
    accountId;
    contactId;
    orderData;
    accountData;
    contactData;
    loading = true;

    @wire(getRecord, { recordId: '$recordId', fields: HANDOFF_FIELDS })
    wiredHandoff({ error, data }) {
        if (data) {
            this.handoffData = data;
            this.orderId = getFieldValue(data, HANDOFF_ORDER);
            this.loading = false;
        } else if (error) {
            this.loading = false;
            this.showErrorToast('Error loading handoff data', error.body?.message || 'Unknown error');
        }
    }

    @wire(getRecord, { recordId: '$orderId', fields: ORDER_FIELDS })
    wiredOrder({ error, data }) {
        if (data) {
            this.orderData = data;
            this.accountId = getFieldValue(data, ORDER_ACCOUNT);
            this.contactId = getFieldValue(data, ORDER_CONTACT);
        } else if (error && this.orderId) {
            console.error('Error loading order:', error);
            this.loading = false;
        }
    }

    @wire(getRecord, { recordId: '$accountId', fields: [ACCOUNT_NAME, ACCOUNT_INDUSTRY] })
    wiredAccount({ error, data }) {
        if (data) {
            this.accountData = data;
        } else if (error && this.accountId) {
            console.error('Error loading account:', error);
        }
    }

    @wire(getRecord, { recordId: '$contactId', fields: [CONTACT_NAME, CONTACT_TITLE] })
    wiredContact({ error, data }) {
        if (data) {
            this.contactData = data;
        } else if (error && this.contactId) {
            console.error('Error loading contact:', error);
        }
    }

    get handoffName() {
        return getFieldValue(this.handoffData, HANDOFF_NAME) || '';
    }

    get accountName() {
        return this.accountData ? getFieldValue(this.accountData, ACCOUNT_NAME) : '';
    }

    get accountIndustry() {
        return this.accountData ? getFieldValue(this.accountData, ACCOUNT_INDUSTRY) : '';
    }

    get contactName() {
        return this.contactData ? getFieldValue(this.contactData, CONTACT_NAME) : '';
    }

    get contactTitle() {
        return this.contactData ? getFieldValue(this.contactData, CONTACT_TITLE) : '';
    }

    get orderNumber() {
        return this.orderData ? getFieldValue(this.orderData, ORDER_NUMBER) : '';
    }

    get productLines() {
        return getFieldValue(this.handoffData, HANDOFF_PRODUCT_LINES) || '';
    }

    get application() {
        return getFieldValue(this.handoffData, HANDOFF_APPLICATION) || '';
    }

    get voltage() {
        return getFieldValue(this.handoffData, HANDOFF_VOLTAGE) || '';
    }

    get amperage() {
        return getFieldValue(this.handoffData, HANDOFF_AMPERAGE) || '';
    }

    get enclosure() {
        return getFieldValue(this.handoffData, HANDOFF_ENCLOSURE) || '';
    }

    get connectorType() {
        return getFieldValue(this.handoffData, HANDOFF_CONNECTOR_TYPE) || '';
    }

    get siteConditions() {
        return getFieldValue(this.handoffData, HANDOFF_SITE_CONDITIONS) || '';
    }

    get customerIntent() {
        return getFieldValue(this.handoffData, HANDOFF_CUSTOMER_INTENT) || '';
    }

    get salesNotes() {
        return getFieldValue(this.handoffData, HANDOFF_SALES_NOTES) || '';
    }

    get status() {
        return getFieldValue(this.handoffData, HANDOFF_STATUS) || '';
    }

    get engineeringNotes() {
        return getFieldValue(this.handoffData, HANDOFF_ENGINEERING_NOTES) || '';
    }

    get peerReviewStatus() {
        return getFieldValue(this.handoffData, HANDOFF_PEER_REVIEW_STATUS) || '';
    }

    get peerReviewNotes() {
        return getFieldValue(this.handoffData, HANDOFF_PEER_REVIEW_NOTES) || '';
    }

    get hasSpecData() {
        return this.voltage || this.amperage || this.enclosure || this.connectorType;
    }

    get hasCustomerContext() {
        return this.accountName || this.contactName;
    }

    get statusBadgeVariant() {
        const status = this.status?.toLowerCase();
        if (status === 'complete') return 'success';
        if (status === 'ready to buy') return 'success';
        if (status === 'peer review') return 'warning';
        if (status === 'in review') return 'info';
        if (status === 'bom created') return 'info';
        if (status === 'drawings created') return 'info';
        if (status === 'pending review') return 'warning';
        return 'default';
    }

    get peerReviewBadgeVariant() {
        const status = this.peerReviewStatus?.toLowerCase();
        if (status === 'pass') return 'success';
        if (status === 'fail') return 'error';
        return 'warning';
    }

    showErrorToast(title, message) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: 'error'
        });
        this.dispatchEvent(evt);
    }

    navigateToAccount() {
        if (this.accountId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.accountId,
                    actionName: 'view'
                }
            });
        }
    }

    navigateToContact() {
        if (this.contactId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.contactId,
                    actionName: 'view'
                }
            });
        }
    }

    handleAccountClick(event) {
        event.preventDefault();
        this.navigateToAccount();
    }

    handleContactClick(event) {
        event.preventDefault();
        this.navigateToContact();
    }
}
