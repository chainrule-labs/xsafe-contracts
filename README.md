# xSafe Predictive Deployer

Deterministic Multi-Chain Deployment

Frontend:

We also handle signatures carefully on frontend

-   Minimize risk of signatures getting stolen
-   After signing, prompt transaction. If submitted, clear state. If not, clear state, prompt sign again.

Contracts:

We only accept signatures relevant to our specific contract functionality

-   No actions can take place that were not directly authorized
-   Stolen signatures, for other means, do not prompt deployments on our factory contract

We mandate that only signer and xsafe can submit signatures for deployment

-   The power to execute a depoyment is limited to salt private key holder and xsafe

Deployment requires signature, not address directly

-   Salt is a function of address - anyone can submit an address. Only private keyholder can submit signature
-   With signature method, the only way to obtain a salt, tied to an address, is to own that address' private key
-   Only rightful owners can deploy their contracts at their deterministic addresses

User nonce is dependent on the bytecode of the function

-   Rationale: user does not need to track the order in which they deploy contracts a, b, c... On chain 1 | b, a, c... On chain 2
-   In an effort to keep the signable transaction hash unique for each transaction, bytecode is included in the has
-   We chose not to include bytecode in the salt because create2 is a hash of the bytecode and the salt.
    -   Even if the salt is the same for contract a and b, they will have different bytecodes and thus different addresses.

Create3 constructor arg independent deployer notes

-   Child address is order-independent so long as the stripped bytecode differs on same chain and different chains
    -   Example: deploy a, b, c in any order you want on different chains and still guarantee correct addresses on each chain
-   Child address is order-dependent multiple contracts share the same stripped bytecode and differing constructor args
    -   Example: on chain 1, deploy person contract with constructor arg, bob; deploy person contract with constructor arg, alice.
        If, on Chain 2, alice contract was deployed before bob contract, the chain 2 alice contract would take the chain 1 bob contract's address.
-   If user messes up constructor args on a single chain, all chain deployments must be redone if address uniformity is required.
    This is true for all multi-chain contract deployments (manual, create2, and create3).
