A blockchain-based estate management platform that revolutionizes how landlords and tenants interact through transparent, automated smart contracts.

## 🚀 Features

### 🎫 NFT-Based Lease Agreements
- Each lease is represented as a unique NFT minted to the tenant
- Immutable lease terms stored on-chain
- Easy transfer and verification of lease ownership

### 💰 Automated Rent Collection
- Monthly rent payments with automatic late fee calculation
- Transparent payment history on blockchain
- Built-in late fee triggers based on configurable rates
- Rent escrow system for pre-funded rent payments

### 🔒 Token Staking for Maintenance Deposits
- Estate tokens for security deposits
- Automated deposit return upon lease termination
- Transparent deposit management

### 🗳️ DAO Governance for Upgrades
- Resident voting on property improvements
- Proposal creation and execution system
- Democratic decision-making for estate enhancements

### 📊 Transparent Expense Tracking
- All maintenance and upgrade costs logged on-chain
- Categorized expense reporting
- Complete financial transparency

## 📋 Core Functions

### Lease Management
- `create-lease` - Create new lease with NFT minting
- `pay-rent` - Process monthly rent payments
- `deposit-rent-escrow` - Pre-fund rent payments in escrow
- `withdraw-rent-escrow` - Use escrowed funds for rent payment
- `terminate-lease` - End lease and return deposits

### Maintenance System
- `submit-maintenance-request` - Tenants request repairs
- `approve-maintenance` - Landlord approval process
- `complete-maintenance` - Mark work as completed
- `stake-maintenance-deposit` - Stake tokens for deposits

### DAO Governance
- `create-proposal` - Submit upgrade proposals
- `vote-on-proposal` - Cast votes on proposals
- `execute-proposal` - Execute approved proposals

### Financial Tracking
- `calculate-late-fee` - Automatic late fee calculation
- Comprehensive expense logging system
- Real-time balance tracking

## 🛠️ Usage Instructions

### For Landlords

1. **Create a lease:**
   ```clarity
   (contract-call? .smart-estate create-lease 
     "123 Main Street" 
     'tenant-principal 
     u1000 
     u2000 
     u52560 
     u5)
   ```

2. **Approve maintenance requests:**
   ```clarity
   (contract-call? .smart-estate approve-maintenance u1)
   ```

3. **Terminate lease:**
   ```clarity
   (contract-call? .smart-estate terminate-lease u1)
   ```

### For Tenants

1. **Pay monthly rent:**
    ```clarity
    (contract-call? .smart-estate pay-rent u1)
    ```

2. **Deposit rent escrow:**
    ```clarity
    (contract-call? .smart-estate deposit-rent-escrow u1 u2000)
    ```

3. **Withdraw from rent escrow:**
    ```clarity
    (contract-call? .smart-estate withdraw-rent-escrow u1)
    ```

2. **Submit maintenance request:**
   ```clarity
   (contract-call? .smart-estate submit-maintenance-request 
     u1 
     "Leaking faucet in kitchen" 
     u200)
   ```

3. **Stake maintenance deposit:**
   ```clarity
   (contract-call? .smart-estate stake-maintenance-deposit u1 u500)
   ```

### For Community Members

1. **Create proposal:**
   ```clarity
   (contract-call? .smart-estate create-proposal 
     "New Playground Equipment" 
     "Install new playground for children" 
     u5000 
     u1008)
   ```

2. **Vote on proposals:**
   ```clarity
   (contract-call? .smart-estate vote-on-proposal u1 true)
   ```

3. **Execute approved proposals:**
   ```clarity
   (contract-call? .smart-estate execute-proposal u1)
   ```

## 📚 Data Structures

### Lease NFT
- Unique identifier for each lease agreement
- Owned by tenant, managed by landlord
- Contains all lease terms and payment history

### Estate Token
- Fungible token for deposits and staking
- Automatically minted for security deposits
- Burned when staked, minted back when returned

### Maintenance Requests
- Trackable repair and improvement requests
- Status progression: pending → approved → completed
- Cost estimation and actual expense tracking

### Proposals
- Community-driven improvement suggestions
- Voting mechanism with time limits
- Automatic execution for approved proposals

### Rent Escrow
- Pre-funded rent payment system
- Automatic withdrawal for monthly payments
- Secure escrow management with contract control

## 🔧 Development Setup

1. Install Clarinet
2. Clone this repository
3. Run tests with `clarinet test`
4. Deploy to testnet with `clarinet deploy`

## 💡 Key Benefits

- **🔍 Transparency:** All transactions and decisions recorded on blockchain
- **⚡ Automation:** Reduce manual processes and human error
- **🤝 Trust:** Smart contracts eliminate need for intermediaries
- **📈 Efficiency:** Streamlined rent collection and maintenance
- **🏛️ Democracy:** Tenant participation in estate improvements
- **💸 Convenience:** Rent escrow eliminates monthly payment friction

## 🔐 Security Features

- Role-based access control
- Input validation and error handling
- Secure token staking mechanisms
- Time-locked voting periods
- Immutable expense logging
- Protected rent escrow with contract-controlled withdrawals

---

Built with ❤️ using Clarity smart contracts on Stacks blockchain
