# 🚛 TransPermitChain v1.0
**Decentralized Transport Permit Management System on Stacks**

## Overview
**TransPermitChain** is a blockchain-based **Transport Permit Management System** built on the **Stacks blockchain** using the **Clarity** smart contract language.

The contract provides a transparent and tamper-proof way to:
- Request, issue, renew, and revoke transport permits.
- Verify permits directly on-chain.
- Manage transport authorities in a decentralized manner.

This project eliminates manual verification, reduces fraud, and enhances trust between citizens, authorities, and transport administrators.

##Roles in the System

| Role | Description | Permissions |
|------|--------------|-------------|
| **Admin** | Deployer or contract owner | Register/revoke authorities, transfer admin rights |
| **Authority** | Authorized transport officers | Approve, renew, and revoke permits |
| **Citizen** | Vehicle owner or applicant | Request new transport permits, view status |

---

## ⚙️ Core Functionalities

### 🧩 Admin Functions
- **Register new authorities:**  
  `(register-authority authority)`
- **Revoke authorities:**  
  `(revoke-authority authority)`
- **Transfer admin rights:**  
  `(transfer-admin new-admin)`

### Citizen Functions
- **Request a permit:**  
  `(request-permit "vehicle-plate-number")`
- **Check request status:**  
  `(get-request request-id)`

### Authority Functions
- **Approve and issue permit:**  
  `(approve-request request-id owner validity-blocks)`
- **Renew existing permit:**  
  `(renew-permit permit-id extra-blocks)`
- **Revoke permit:**  
  `(revoke-permit permit-id)`

###Verification Functions
- **Verify a permit:**  
  `(verify-permit permit-id)`
- **Find permit by vehicle number:**  
  `(get-permit-by-vehicle "vehicle-plate-number")`
- **Check total requests or permits:**  
  `(get-request-count)` / `(get-permit-count)`

##  Contract Design Summary

| Component | Description |
|------------|-------------|
| **Variables** | Store admin address and ID counters for requests and permits |
| **Maps** | Maintain records of authorities, requests, permits, and vehicle lookups |
| **Authorization Logic** | Restricts sensitive actions to specific roles |
| **Permit Lifecycle** | Requests → Approval → Issuance → Renewal/Revocation |
| **Validation Rules** | Prevents invalid vehicle numbers, empty strings, or expired actions |

---

## Deployment Guide

### Prerequisites
- [Clarinet](https://docs.stacks.co/docs/clarinet/overview) installed  
- Git installed on your system

### Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/<your-username>/TransPermitChain.git
   cd TransPermitChain
