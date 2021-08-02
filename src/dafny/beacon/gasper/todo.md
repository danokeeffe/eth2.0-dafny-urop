
verificaiton status:
- forkchoice V
- attestations V
- helpers V
- validators V
- crypto V
- merkle V
- beacon V
- ssz V
- utils V
- gasper V
- statetransition


- clean up files (remove comments)
    - forkchoice V + doc [DONE]
    - attestations V + doc [DONE]
    - helpers [X]
    - validators V + doc [DONE]
    - crypto [X]
    - merkle V + doc [DONE]
    - beacon V + doc [DONE]
    - ssz V + doc [DONE]
    - utils V + doc [DONE]
    - gasper V + doc [DONE]
    - statetransition
- documentation V
- update copyright to 2021 V

- build call graphs
- forkchoice V + doc [DONE]
    - attestations 
    - helpers 
    - validators 
    - crypto 
    - merkle 
    - beacon 
    - ssz 
    - utils 
    - gasper 
    - statetransition


- readme with limitations

- docker with correct Dafnhy machine toi check
- remove square_root code



- prove stateTransition + justification
- prove on_block [cannot be done]
- remove two assumes (get_block_root in nextSlot [try?]
- try to localise assume in magic lemma: remove from resolveStateRoot [not possible]

- nice to have: 
    - add teo justification proof to Gasper
    - integrate justification in stateTransition

- integrate with justification bits
- integrate with 1-finalisation bits  

- proof for two finalisation
 - def of two finalisation
 - new version of lemma 5 for two finalisation

- [NOT DONE] use IndecxAttestations and remove the REGISTRY_LIMIT constraint.

Monday:
- [DONE] finish proof of lemma5 for one finalisation
- [HARD] add ruleI and ruleII, and show 1-finalisation OK except breaking ruleI or ruleII
- [DONE] start 2-finalise

Tuesday:
- finish 2-finalise
- prove that state_transitions functions maintain properties of canonical chain. 

to check:

- epoch processing defs of EBBs, justified



//

1. prove that an EBB is justified (in code) iff is justified by definition
    
2. for finalisation, try to do the same as 1. using only one way of finalising EBB 
    (for safety this is enough), although we probably only prove the if direction only. 


Proofs:
a. s.current_justified_checkpoint must be the highest epoch justified checkpoint 
b. valid attestations must have s.current_justified_checkpoint as source 
    because we copy them into previous_attestations same applies to previous_attestations 
c. consequence: a supermajority link in s.current_attestations must be from 
    s.current_justified_checkpoint 
d. because this one is justified, then updateJustification is correct.

need to change definition of justified.
1. use only attestations for target epoch i 
2. assume epochs prior i are defined as justified or not 

start with 1-finalisation to prove property lemma 5.11