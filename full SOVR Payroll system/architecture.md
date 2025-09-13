# System Flow Architecture

This diagram illustrates the end-to-end data and execution flow of the SOVR Payroll system.

```mermaid
flowchart LR
    EMP[Employee Wallet] -- claimSalary() --> PAYROLL[AutoPayroll.sol]
    PAYROLL -- emits SalaryClaimed --> CONSUL[Consul Listener (Node)]
    CONSUL -- Stripe API --> STRIPE[Stripe Treasury/Connect]
    STRIPE -- Payout Transfer --> BANK[(Bank / Card Via Stripe)]
    CONSUL -- burn() --> SOVRC[SOVRCredit.sol]
    PAYROLL -.stores salaries.-> SOVRC
```