# Algorithm verification, tool version 1.0.0-rc.4

Overall result: **PASSED**. 26 signalling questions in 6 domains.

| Domain | Valid answer profiles | Low | Some concerns | High | Exclusive | Skip logic | All judgments reachable | Monotonic (comparisons) | Dead questions |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| D1 | 85 | 4 | 29 | 52 | yes | yes | yes | yes (456) | none |
| D2 | 425 | 32 | 163 | 230 | yes | yes | yes | yes (2960) | none |
| D3 | 2801 | 16 | 1697 | 1088 | yes | yes | yes | yes (23488) | none |
| D4 | 1325 | 32 | 283 | 1010 | yes | yes | yes | yes (12440) | none |
| D5 | 2750 | 80 | 586 | 2084 | yes | yes | yes | yes (30700) | none |
| D6 | 125 | 8 | 37 | 80 | yes | yes | yes | yes (600) | none |

Overall rule: 957 domain-judgment profiles (including O1 answers); never below the worst domain: yes; monotonic: yes.

Properties checked for every domain:

1. **Exclusive:** no answer profile satisfies both the Low and the High rule.
2. **Skip logic:** a question is answered exactly when its condition holds.
3. **Reachable:** Low, Some concerns and High each occur.
4. **Monotonic:** replacing any answer with a worse one (for that question's polarity; NI ranks between yes and no) never gives a better judgment, for every way of answering follow-up questions that become applicable.
5. **No dead questions:** every question can change the judgment.
