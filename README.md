# ✈ BidPilot — SOW to Proposal in 3 minutes (Agentforce)

BidPilot is an Agentforce agent for IT consulting teams. Give it a client SOW/RFP and it
extracts the scope, estimates effort against your own delivery history, staffs a team from
available resources, scores the risk, routes risky bids to a manager, and produces the
Opportunity, delivery tasks, proposal summary and client email.

**Pain it solves:** preparing one proposal takes 3–5 days of senior people's time.
BidPilot turns that into a 3-minute conversation, with a human approving every risky bid.

---

## 1. Deploy (one command)

Prerequisites: Salesforce CLI (`sf`), an org with **Agentforce enabled**
(an Agentforce-enabled Developer Edition org works), and you are logged in:

```bash
sf org login web --alias bidpilot
./deploy.sh bidpilot
```

`deploy.sh` deploys all metadata, assigns the `BidPilot_User` permission set, loads demo
data (8 resources, 6 past projects, sample bid for *Nila Logistics*) and runs the Apex tests.

## 2. Add the live dashboard to the Bid page (1 minute)

1. Open any Bid record → ⚙ → **Edit Page**.
2. Drag **BidPilot Dashboard** (Custom components) to the top of the main region.
3. **Save → Activate → Assign as Org Default**.

The dashboard polls every 4 seconds, so judges watch the bid fill in live while the agent works.

## 3. Configure the agent in Agentforce Builder (10 minutes)

1. **Setup → Einstein Setup** → turn on Einstein.
   **Setup → Agentforce Agents** → turn on Agentforce.
2. **New Agent** → choose the **Agentforce Employee Agent** template. Name it **BidPilot**.
3. Create a new topic with the settings below.
4. Under the topic's **This Topic's Actions**, choose **New → Create new action**,
   set *Reference Action Type* = **Apex**, and add each action (they are all grouped
   under the *BidPilot* category):

   | Action | Input: require input | Output: show in conversation |
   |---|---|---|
   | BidPilot: Create Bid from SOW | all | Message |
   | BidPilot: Get SOW Content | Bid Reference | — |
   | BidPilot: Save SOW Analysis | Bid Reference, Modules JSON | Message |
   | BidPilot: Estimate Effort | Bid Reference | Message |
   | BidPilot: Suggest Team | Bid Reference | Team Summary, Message |
   | BidPilot: Assess Risk | Bid Reference | Risk Breakdown, Message |
   | BidPilot: Record Approval Decision | Bid Reference, Decision | Message |
   | BidPilot: Generate Proposal | Bid Reference | Client Email Draft, Message |

5. **Activate** the agent. Make sure your user has the `BidPilot_User` permission set.
6. Open a Bid record and launch the agent from the Agentforce (✦) panel.

### Topic: Bid Preparation

**Classification description**
> Handles requests to analyse a client statement of work (SOW) or RFP, prepare a bid,
> estimate effort, suggest a delivery team, assess bid risk, approve or reject a bid,
> and generate a proposal or client email.

**Scope**
> Your job is to turn a client SOW into an approved, priced proposal using only the
> BidPilot actions and the data they return. You do not answer unrelated questions.

**Instructions** (add each as a separate instruction)

1. Work out which bid the user means. If they are on a Bid record page, use that record's Id as the Bid Reference. If they give a bid number such as BID-0001, use it. If they paste a new SOW that is not saved yet, first run "BidPilot: Create Bid from SOW".
2. Before analysing, always run "BidPilot: Get SOW Content". Never invent scope that is not in the SOW.
3. Read the SOW and break it into 4 to 10 delivery modules. For each module give a name, a complexity (High for external system integrations, undecided requirements or vendors, or heavy custom code; Medium for standard custom work; Low for configuration), one primary skill from this list: Experience Cloud, Service Cloud, Apex, LWC, Flow, Integration, Data Migration, Reports, React Native, WhatsApp, and a one-line description.
4. Also list the tech stack and every risk you find in the SOW: missing documentation, vendors not finalised, vague requirements, penalty clauses, tight deadlines, limited client availability. Then run "BidPilot: Save SOW Analysis" with the modules as a JSON array, for example [{"name":"Customer Portal","complexity":"High","skill":"Experience Cloud","description":"B2B self-service portal"}], and the risks one per line.
5. After saving the analysis, run these without asking the user in between: "BidPilot: Estimate Effort", then "BidPilot: Suggest Team", then "BidPilot: Assess Risk".
6. After the risk assessment, reply with a short summary: number of modules, total hours, duration in weeks compared with what the client asked for, cost in INR, the team with any open positions, and the risk score with its top three reasons.
7. If "Requires Approval" is true, say clearly that the bid is waiting for manager approval and stop. Never generate a proposal for a bid that is not approved.
8. Only run "BidPilot: Record Approval Decision" when the user explicitly says they approve or reject the bid. Pass their words as Comments.
9. When the bid is approved and the user asks for the proposal, run "BidPilot: Generate Proposal" and show the client email draft.
10. Never change the numbers returned by the actions. Show money in INR.

---

## 4. Five-minute demo script

| Time | Say / do | What the judges see |
|---|---|---|
| 0:00 | "Preparing a proposal takes us 3–5 days. Watch this." Open **BID-0001** (Nila Logistics SOW). | Dashboard in *Draft* |
| 0:30 | In Agentforce: **"Analyse this SOW and prepare the bid."** | Modules appear, then hours, team cards, risk gauge, live |
| 2:00 | Point at the gauge: **High risk** — 8-week deadline vs real duration, SAP docs missing, WhatsApp vendor not chosen, 2%/week penalty. | Status *Pending Approval*, bell notification for manager |
| 2:45 | As manager: **"Approve BID-0001, add a 2-week buffer to the timeline."** (or click Approve on the dashboard) | Status *Approved* |
| 3:15 | **"Generate the proposal and client email."** | Opportunity + delivery tasks created, proposal and email tabs |
| 4:00 | ROI slide: 3 days → 3 minutes; estimates calibrated on *our* past overruns; humans approve risky bids. | |

Tip: record a backup video of this exact flow before the demo.

## 5. How it works

```
SOW ──► Agentforce (LLM reasoning: extract modules, skills, risks)
          │
          ├─ Save SOW Analysis ─► Bid_Module__c
          ├─ Estimate Effort ───► base hours × calibration from Past_Project__c (actual/planned) + 25% QA/PM
          ├─ Suggest Team ──────► Resource__c matched by skill, lowest allocation first → Bid_Team_Member__c
          ├─ Assess Risk ───────► timeline gap + complexity + skill gaps + SOW risks + past overruns
          │                          High ⇒ Pending Approval, Task + bell notification to manager
          ├─ Approval ──────────► human-in-the-loop (agent or dashboard button)
          └─ Generate Proposal ─► Account, Opportunity, delivery Tasks, proposal, client email
```

The LLM does what it is good at (reading messy SOWs); the numbers come from deterministic,
tested Apex, so the estimate is explainable and repeatable.

### Data model
- **Bid__c** — the SOW, status, totals, risk, proposal, email
- **Bid_Module__c** (master-detail) — scope modules with complexity, skill, hours
- **Bid_Team_Member__c** (master-detail) — suggested resources or open positions
- **Resource__c** — people, skills, rate, current allocation
- **Past_Project__c** — delivered projects with planned vs actual effort

### Tuning
Base hours (Low 40 / Medium 100 / High 200), overhead (1.25), INR default rate and risk
thresholds are constants at the top of `BidPilotService.cls`.
