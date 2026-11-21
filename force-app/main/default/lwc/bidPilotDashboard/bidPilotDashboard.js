import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getBidData from '@salesforce/apex/BidPilotDashboardController.getBidData';
import decide from '@salesforce/apex/BidPilotDashboardController.decide';

const POLL_MS = 4000;
const FLASH_MS = 1600;
const ARC = 251.33; // half circumference for r = 80
const STEPS = ['Draft', 'Analyzed', 'Estimated', 'Team Assigned', 'Approval', 'Proposal Ready'];
const STATUS_INDEX = {
    Draft: 0, Analyzed: 1, Estimated: 2, 'Team Assigned': 3,
    'Pending Approval': 4, Approved: 4, Rejected: 4, 'Proposal Ready': 5
};
const STATUS_EVENT = {
    Analyzed: 'Scope extracted from the SOW',
    Estimated: 'Effort estimated and calibrated on past projects',
    'Team Assigned': 'Team staffed from available resources',
    'Pending Approval': 'High risk detected, sent to manager for approval',
    Approved: 'Bid approved',
    Rejected: 'Bid rejected',
    'Proposal Ready': 'Proposal, opportunity and client email generated'
};

export default class BidPilotDashboard extends NavigationMixin(LightningElement) {
    @api recordId;
    @track data;
    error;
    activeTab = 'proposal';
    comments = '';
    busy = false;
    flash = {};
    lastEvent;
    lastEventAt;
    now = Date.now();
    _timer;
    _snapshot;

    connectedCallback() {
        this.load();
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._timer = setInterval(() => {
            this.now = Date.now();
            this.load();
        }, POLL_MS);
    }

    disconnectedCallback() {
        clearInterval(this._timer);
    }

    async load() {
        if (!this.recordId) return;
        try {
            const result = await getBidData({ bidId: this.recordId });
            const snapshot = JSON.stringify(result);
            if (snapshot !== this._snapshot) {
                if (this.data) this.markChanges(this.data, result);
                this._snapshot = snapshot;
                this.data = result;
            }
            this.error = undefined;
        } catch (e) {
            this.error = e?.body?.message || e?.message || 'Unable to load bid';
        }
    }

    markChanges(prev, next) {
        const keys = {
            hours: prev.totalHours !== next.totalHours,
            cost: prev.cost !== next.cost,
            weeks: prev.durationWeeks !== next.durationWeeks,
            team: (prev.team || []).length !== (next.team || []).length,
            risk: prev.riskScore !== next.riskScore,
            modules: (prev.modules || []).length !== (next.modules || []).length
        };
        const changed = Object.keys(keys).filter((k) => keys[k]);
        if (prev.status !== next.status && STATUS_EVENT[next.status]) {
            this.lastEvent = STATUS_EVENT[next.status];
            this.lastEventAt = Date.now();
        }
        if (!changed.length) return;
        const f = {};
        changed.forEach((k) => (f[k] = true));
        this.flash = f;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => (this.flash = {}), FLASH_MS);
    }

    // ---------------------------------------------------------------- helpers
    fmt(v, digits = 0) {
        if (v === null || v === undefined) return null;
        return Number(v).toLocaleString('en-IN', { maximumFractionDigits: digits });
    }
    money(v) {
        if (v === null || v === undefined) return null;
        if (v >= 10000000) return '₹' + (v / 10000000).toFixed(2) + ' Cr';
        if (v >= 100000) return '₹' + (v / 100000).toFixed(2) + ' L';
        return '₹' + this.fmt(v);
    }

    // ---------------------------------------------------------------- header
    get hasData() {
        return !!this.data;
    }
    get showSpinner() {
        return !this.data && !this.error;
    }
    get statusClass() {
        const s = (this.data?.status || 'Draft').toLowerCase().replace(/\s+/g, '-');
        return `status-pill status-${s}`;
    }
    get stepIndex() {
        return STATUS_INDEX[this.data?.status] ?? 0;
    }
    get progressPct() {
        const done = ['Proposal Ready'].includes(this.data?.status) ? 6
            : this.data?.status === 'Approved' ? 5 : this.stepIndex;
        return Math.round((done / 6) * 100);
    }
    get progressStyle() {
        return `width:${this.progressPct}%`;
    }
    get progressText() {
        return `${this.progressPct}% complete`;
    }
    get requestedText() {
        return this.data?.requestedWeeks ? `${this.data.requestedWeeks} wk deadline` : 'No deadline';
    }
    get hasTech() {
        return !!this.data?.techStack;
    }
    get techChips() {
        return (this.data?.techStack || '').split(',').map((t, i) => ({ key: i, label: t.trim() })).filter((t) => t.label);
    }
    get hasEvent() {
        return !!this.lastEvent;
    }
    get eventAgo() {
        if (!this.lastEventAt) return '';
        const s = Math.max(0, Math.round((this.now - this.lastEventAt) / 1000));
        return s < 5 ? 'just now' : s < 60 ? `${s}s ago` : `${Math.round(s / 60)}m ago`;
    }
    get isWorking() {
        // Agent is mid-pipeline (analysed but not yet risk-scored)
        return ['Analyzed', 'Estimated', 'Team Assigned'].includes(this.data?.status);
    }

    get steps() {
        const current = this.stepIndex;
        const status = this.data?.status;
        const finished = ['Proposal Ready', 'Approved'].includes(status);
        return STEPS.map((label, i) => {
            let state = 'todo';
            if (i < current || (i === current && finished)) state = 'done';
            else if (i === current) state = status === 'Rejected' ? 'rejected' : status === 'Pending Approval' ? 'waiting' : 'active';
            let text = label;
            if (i === 4 && status === 'Rejected') text = 'Rejected';
            else if (i === 4 && status === 'Pending Approval') text = 'Awaiting approval';
            else if (i === 4 && status === 'Approved') text = 'Approved';
            return { key: label, label: text, num: state === 'done' ? '✓' : i + 1, cls: `step step-${state}` };
        });
    }

    // ---------------------------------------------------------------- KPIs
    kpiCls(key) {
        return this.flash[key] ? 'kpi flash' : 'kpi';
    }
    get hoursCls() { return this.kpiCls('hours'); }
    get costCls() { return this.kpiCls('cost'); }
    get weeksCls() { return this.kpiCls('weeks'); }
    get teamCls() { return this.kpiCls('team'); }

    get hasHours() { return this.data?.totalHours != null; }
    get hoursText() { return this.fmt(this.data?.totalHours); }
    get calibrationText() {
        const c = this.data?.calibration;
        if (!c) return 'Rate card × past-project calibration';
        const pct = Math.round((c - 1) * 100);
        return pct > 0 ? `+${pct}% from past overruns` : pct < 0 ? `${pct}% from past projects` : 'Matches past projects';
    }

    get hasCost() { return this.data?.cost != null; }
    get costText() { return this.money(this.data?.cost); }
    get costSub() {
        const h = this.data?.totalHours;
        const c = this.data?.cost;
        return h && c ? `≈ ₹${this.fmt(c / h)} per hour blended` : 'From team hourly rates';
    }

    get hasWeeks() { return this.data?.durationWeeks != null; }
    get weeksText() { return this.fmt(this.data?.durationWeeks, 1); }
    get isLate() {
        const d = this.data;
        return !!(d?.durationWeeks && d?.requestedWeeks && d.durationWeeks > d.requestedWeeks);
    }
    get weeksSub() {
        const d = this.data;
        if (!d?.requestedWeeks) return 'No client deadline';
        if (!d?.durationWeeks) return `Client asked ${d.requestedWeeks} wks`;
        const diff = Math.round((d.durationWeeks - d.requestedWeeks) * 10) / 10;
        return diff > 0 ? `${diff} wks over the ${d.requestedWeeks}-wk deadline` : `Fits the ${d.requestedWeeks}-wk deadline`;
    }
    get weeksSubCls() {
        return this.isLate ? 'kpi-sub bad' : 'kpi-sub good';
    }
    get showTimelineBar() {
        return !!(this.data?.durationWeeks && this.data?.requestedWeeks);
    }
    get timelineMax() {
        return Math.max(this.data?.durationWeeks || 0, this.data?.requestedWeeks || 0) || 1;
    }
    get requestedBarStyle() {
        return `width:${(this.data.requestedWeeks / this.timelineMax) * 100}%`;
    }
    get estimatedBarStyle() {
        return `width:${(this.data.durationWeeks / this.timelineMax) * 100}%`;
    }
    get estimatedBarCls() {
        return this.isLate ? 'tl-fill tl-bad' : 'tl-fill tl-good';
    }

    get teamCount() { return this.data?.team?.length || 0; }
    get hasTeam() { return this.teamCount > 0; }
    get gapCount() { return (this.data?.team || []).filter((t) => t.isOpen).length; }
    get teamSub() {
        if (!this.hasTeam) return 'Staffed after estimation';
        return this.gapCount ? `${this.gapCount} open position${this.gapCount > 1 ? 's' : ''} to hire` : 'All skills covered in-house';
    }
    get teamSubCls() {
        return this.hasTeam && this.gapCount ? 'kpi-sub bad' : 'kpi-sub';
    }

    // ---------------------------------------------------------------- risk
    get hasRisk() {
        return this.data?.riskScore !== null && this.data?.riskScore !== undefined;
    }
    get riskScoreText() { return this.hasRisk ? this.data.riskScore : '—'; }
    get riskDash() {
        return `${((this.hasRisk ? this.data.riskScore : 0) / 100) * ARC} ${ARC}`;
    }
    get riskColor() {
        const l = this.data?.riskLevel;
        if (l === 'High') return '#e5484d';
        if (l === 'Medium') return '#f5a524';
        if (l === 'Low') return '#30a46c';
        return '#cfd3dc';
    }
    get riskPillCls() {
        return `risk-pill risk-${(this.data?.riskLevel || 'none').toLowerCase()}`;
    }
    get riskLevelText() {
        return this.hasRisk ? `${this.data.riskLevel} risk` : 'Not assessed yet';
    }
    get riskCardCls() {
        return this.flash.risk ? 'card flash' : 'card';
    }
    get riskReasons() {
        return (this.data?.riskBreakdown || '').split('\n').filter((l) => l.trim()).map((l, i) => {
            const m = l.match(/\(\+(\d+)\)\s*$/);
            return { key: i, text: m ? l.replace(m[0], '').trim() : l, pts: m ? `+${m[1]}` : '' };
        });
    }
    get sowRisks() {
        return (this.data?.riskFactors || '').split(/\n|;/).filter((l) => l.trim()).map((l, i) => ({ key: i, text: l.trim() }));
    }
    get hasSowRisks() { return this.sowRisks.length > 0; }

    // ---------------------------------------------------------------- modules
    get modules() {
        const list = this.data?.modules || [];
        const max = Math.max(1, ...list.map((m) => m.hours || 0));
        return list.map((m) => {
            const c = (m.complexity || 'Medium').toLowerCase();
            return {
                ...m,
                hoursText: m.hours ? `${this.fmt(m.hours)} h` : '—',
                badge: `badge badge-${c}`,
                barCls: `bar-fill bar-${c}`,
                barStyle: `width:${Math.max(4, Math.round(((m.hours || 0) / max) * 100))}%`
            };
        });
    }
    get hasModules() { return this.modules.length > 0; }
    get modulesCls() { return this.flash.modules ? 'card span2 flash' : 'card span2'; }
    get complexityMix() {
        const count = (c) => (this.data?.modules || []).filter((m) => m.complexity === c).length;
        return [
            { key: 'h', label: `${count('High')} High`, cls: 'mix mix-high' },
            { key: 'm', label: `${count('Medium')} Medium`, cls: 'mix mix-medium' },
            { key: 'l', label: `${count('Low')} Low`, cls: 'mix mix-low' }
        ];
    }
    get similar() {
        return (this.data?.similarProjects || '').split('\n').filter((l) => l.trim()).map((l, i) => ({ key: i, text: l }));
    }
    get hasSimilar() { return this.similar.length > 0; }

    // ---------------------------------------------------------------- team
    get team() {
        return (this.data?.team || []).map((t) => ({
            ...t,
            initials: t.isOpen ? '+' : (t.name || '?').split(' ').map((p) => p[0]).join('').slice(0, 2).toUpperCase(),
            cardCls: t.isOpen ? 'member member-open' : 'member',
            displayName: t.isOpen ? 'Open position' : t.name,
            allocText: `${this.fmt(t.allocation)}%`,
            allocStyle: `width:${Math.min(100, t.allocation || 0)}%`,
            hoursText: `${this.fmt(t.hours)} h`,
            costText: this.money(t.cost) || '—'
        }));
    }
    get teamTotal() { return this.money(this.data?.cost) || '—'; }

    // ---------------------------------------------------------------- approval
    get isPending() { return this.data?.status === 'Pending Approval'; }
    handleComments(e) { this.comments = e.target.value; }
    handleApprove() { this.submitDecision('Approve'); }
    handleReject() { this.submitDecision('Reject'); }
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

    // ---------------------------------------------------------------- proposal
    get hasProposal() { return !!(this.data?.proposal || this.data?.email); }
    get isProposalTab() { return this.activeTab === 'proposal'; }
    get proposalTabCls() { return this.isProposalTab ? 'tab tab-active' : 'tab'; }
    get emailTabCls() { return this.isProposalTab ? 'tab' : 'tab tab-active'; }
    get docText() { return this.isProposalTab ? this.data?.proposal : this.data?.email; }
    showProposal() { this.activeTab = 'proposal'; }
    showEmail() { this.activeTab = 'email'; }
    async copyDoc() {
        try {
            await navigator.clipboard.writeText(this.docText || '');
            this.toast('Copied', 'Copied to clipboard', 'success');
        } catch (e) {
            this.toast('Copy failed', 'Select the text and copy manually', 'warning');
        }
    }
    get hasOpportunity() { return !!this.data?.opportunityId; }
    openOpportunity() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.data.opportunityId, objectApiName: 'Opportunity', actionName: 'view' }
        });
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
