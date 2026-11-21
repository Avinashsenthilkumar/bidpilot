import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getBidData from '@salesforce/apex/BidPilotDashboardController.getBidData';
import decide from '@salesforce/apex/BidPilotDashboardController.decide';

const POLL_MS = 4000;
const ARC = 251.33; // half circumference for r = 80
const STEPS = ['Draft', 'Analyzed', 'Estimated', 'Team Assigned', 'Approval', 'Proposal Ready'];
const STATUS_INDEX = {
    Draft: 0, Analyzed: 1, Estimated: 2, 'Team Assigned': 3,
    'Pending Approval': 4, Approved: 4, Rejected: 4, 'Proposal Ready': 5
};

export default class BidPilotDashboard extends NavigationMixin(LightningElement) {
    @api recordId;
    @track data;
    error;
    activeTab = 'proposal';
    comments = '';
    busy = false;
    _timer;
    _lastSnapshot;

    connectedCallback() {
        this.load();
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._timer = setInterval(() => this.load(), POLL_MS);
    }

    disconnectedCallback() {
        clearInterval(this._timer);
    }

    async load() {
        if (!this.recordId) return;
        try {
            const result = await getBidData({ bidId: this.recordId });
            const snapshot = JSON.stringify(result);
            if (snapshot !== this._lastSnapshot) {
                this._lastSnapshot = snapshot;
                this.data = result;
            }
            this.error = undefined;
        } catch (e) {
            this.error = e?.body?.message || e?.message || 'Unable to load bid';
        }
    }

    // ---------- header / steps
    get hasData() {
        return !!this.data;
    }

    get showSpinner() {
        return !this.data && !this.error;
    }

    get steps() {
        const current = STATUS_INDEX[this.data?.status] ?? 0;
        const rejected = this.data?.status === 'Rejected';
        const pending = this.data?.status === 'Pending Approval';
        return STEPS.map((label, i) => {
            let state = 'todo';
            const finished = ['Proposal Ready', 'Approved'].includes(this.data?.status);
            if (i < current || (i === current && finished)) state = 'done';
            else if (i === current) state = rejected ? 'rejected' : (pending ? 'waiting' : 'active');
            let text = label;
            if (i === 4 && rejected) text = 'Rejected';
            else if (i === 4 && pending) text = 'Awaiting Approval';
            else if (i === 4 && this.data?.status === 'Approved') text = 'Approved';
            return { key: label, label: text, num: i + 1, cls: `step step-${state}` };
        });
    }

    get statusClass() {
        const s = (this.data?.status || 'Draft').toLowerCase().replace(/\s+/g, '-');
        return `status-pill status-${s}`;
    }

    // ---------- KPIs
    fmtNum(v, digits = 0) {
        if (v === null || v === undefined) return '—';
        return Number(v).toLocaleString('en-IN', { maximumFractionDigits: digits });
    }

    get hoursText() {
        return this.fmtNum(this.data?.totalHours);
    }
    get costText() {
        const v = this.data?.cost;
        if (v === null || v === undefined) return '—';
        if (v >= 100000) return '₹' + (v / 100000).toFixed(2) + ' L';
        return '₹' + this.fmtNum(v);
    }
    get weeksText() {
        return this.fmtNum(this.data?.durationWeeks, 1);
    }
    get requestedText() {
        return this.data?.requestedWeeks ? `Client asked ${this.data.requestedWeeks} wks` : 'No deadline given';
    }
    get timelineClass() {
        const d = this.data;
        const over = d?.durationWeeks && d?.requestedWeeks && d.durationWeeks > d.requestedWeeks;
        return over ? 'kpi-sub warn' : 'kpi-sub';
    }
    get calibrationText() {
        return this.data?.calibration ? `×${this.data.calibration} from history` : 'Not calibrated yet';
    }
    get teamCount() {
        return this.data?.team?.length || 0;
    }
    get gapCount() {
        return (this.data?.team || []).filter((t) => t.isOpen).length;
    }
    get gapText() {
        return this.gapCount ? `${this.gapCount} open position(s)` : 'All skills covered';
    }

    // ---------- risk gauge
    get hasRisk() {
        return this.data?.riskScore !== null && this.data?.riskScore !== undefined;
    }
    get riskScore() {
        return this.hasRisk ? this.data.riskScore : 0;
    }
    get riskDash() {
        return `${(this.riskScore / 100) * ARC} ${ARC}`;
    }
    get riskColor() {
        const l = this.data?.riskLevel;
        if (l === 'High') return '#e5484d';
        if (l === 'Medium') return '#f5a524';
        return '#30a46c';
    }
    get riskLevelText() {
        return this.hasRisk ? `${this.data.riskLevel} risk` : 'Not assessed';
    }
    get riskReasons() {
        return (this.data?.riskBreakdown || '')
            .split('\n')
            .filter((l) => l.trim())
            .map((l, i) => ({ key: i, text: l }));
    }
    get sowRisks() {
        return (this.data?.riskFactors || '')
            .split(/\n|;/)
            .filter((l) => l.trim())
            .map((l, i) => ({ key: i, text: l.trim() }));
    }

    // ---------- modules / team
    get modules() {
        const max = Math.max(1, ...(this.data?.modules || []).map((m) => m.hours || 0));
        return (this.data?.modules || []).map((m) => ({
            ...m,
            hoursText: m.hours ? `${this.fmtNum(m.hours)}h` : '—',
            badge: `badge badge-${(m.complexity || 'medium').toLowerCase()}`,
            barStyle: `width:${Math.round(((m.hours || 0) / max) * 100)}%`
        }));
    }
    get hasModules() {
        return this.modules.length > 0;
    }
    get team() {
        return (this.data?.team || []).map((t) => ({
            ...t,
            initials: t.isOpen ? '?' : (t.name || '?').split(' ').map((p) => p[0]).join('').slice(0, 2).toUpperCase(),
            cardCls: t.isOpen ? 'member member-open' : 'member',
            allocText: `${this.fmtNum(t.allocation)}%`,
            hoursText: `${this.fmtNum(t.hours)}h`
        }));
    }
    get hasTeam() {
        return this.teamCount > 0;
    }
    get similar() {
        return (this.data?.similarProjects || '')
            .split('\n')
            .filter((l) => l.trim())
            .map((l, i) => ({ key: i, text: l }));
    }
    get hasSimilar() {
        return this.similar.length > 0;
    }

    // ---------- approval
    get isPending() {
        return this.data?.status === 'Pending Approval';
    }
    handleComments(e) {
        this.comments = e.target.value;
    }
    handleApprove() {
        this.submitDecision('Approve');
    }
    handleReject() {
        this.submitDecision('Reject');
    }
    async submitDecision(decision) {
        this.busy = true;
        try {
            const msg = await decide({ bidId: this.recordId, decision, comments: this.comments });
            this.toast(decision === 'Approve' ? 'Approved' : 'Rejected', msg, decision === 'Approve' ? 'success' : 'warning');
            this.comments = '';
            await this.load();
        } catch (e) {
            this.toast('Error', e?.body?.message || 'Failed', 'error');
        } finally {
            this.busy = false;
        }
    }

    // ---------- proposal / email
    get hasProposal() {
        return !!(this.data?.proposal || this.data?.email);
    }
    get isProposalTab() {
        return this.activeTab === 'proposal';
    }
    get proposalTabCls() {
        return this.isProposalTab ? 'tab tab-active' : 'tab';
    }
    get emailTabCls() {
        return this.isProposalTab ? 'tab' : 'tab tab-active';
    }
    get docText() {
        return this.isProposalTab ? this.data?.proposal : this.data?.email;
    }
    showProposal() {
        this.activeTab = 'proposal';
    }
    showEmail() {
        this.activeTab = 'email';
    }
    async copyDoc() {
        try {
            await navigator.clipboard.writeText(this.docText || '');
            this.toast('Copied', 'Copied to clipboard', 'success');
        } catch (e) {
            this.toast('Copy failed', 'Select the text and copy manually', 'warning');
        }
    }
    openOpportunity() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.data.opportunityId, objectApiName: 'Opportunity', actionName: 'view' }
        });
    }
    get hasOpportunity() {
        return !!this.data?.opportunityId;
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
