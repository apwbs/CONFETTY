# CONFETTY

This repository contains the implementation of the CONFidentiality EnforcemenT TransparencY (CONFETTY) approach submitted at the 23rd International Conference on Business Process Management (BPM 2025), [BPM 25]([https://www.bpm2025seville.org/]).

CONFETTY is an architecture for blockchain-based process enactment that preserves the confidentiality of exchanged information while keeping public enforcement and transparency of process execution. In particular, we rely on smart contracts to encode and execute business process logic while logging the interactions between parties, and we resort to Multi-Authority Attribute-Based Encryption (MA-ABE) to control the access of different parties to the activities’ data payloads and information artifacts, thus safeguarding confidentiality.

## Wiki
For detailed documentation and a step-by-step tutorial on configuring and testing this version locally, refer to Wiki.pdf.

## This repository
In this repository, you find several folders necessary to run the system:
1. In the *Confidentiality Manager* folder, you find all the necessary files to run the Confidentiality Manager.
2. In the *Evaluation tool* folder you can find the tool used to run all the tests and to produce the ``Execution Analysis'' of the paper.
3. The *Performance Analysis* folder contains all the images of the tests performed with their cost and time tables.
4. The *Process Manager* folder contains the files needed to run the Process Manager.
5. The *Running example files* folder contains the two files used as inputs for the running example of the paper (an X-ray BPMN choreography), and the references to the deployed smart contracts where you can find all the transactions.
