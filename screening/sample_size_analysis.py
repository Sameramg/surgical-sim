import math

def lchoose(n,k):
    if k<0 or k>n or n<0: return float('-inf')
    return math.lgamma(n+1)-math.lgamma(k+1)-math.lgamma(n-k+1)

def binom_sf(k,n,p):
    """P(X>=k) computed stably"""
    if k<=0: return 1.0
    if k>n: return 0.0
    if p<=0: return 0.0
    if p>=1: return 1.0
    lo=sum(math.exp(lchoose(n,i)+i*math.log(p)+(n-i)*math.log1p(-p)) for i in range(0,k))
    return max(0.0,1.0-lo)

def cp_lower(k,n,alpha):
    if k==0: return 0.0
    if k==n: return alpha**(1.0/n)
    lo,hi=0.0,1.0
    for _ in range(60):
        mid=(lo+hi)/2
        if binom_sf(k,n,mid) < alpha: lo=mid
        else: hi=mid
    return (lo+hi)/2

def positives_needed(target,misses,alpha):
    """smallest n (total positives) with `misses` FNs giving CP lower bound >= target"""
    lo,hi=misses+1,1
    while True:
        hi=max(misses+1,hi*2)
        if cp_lower(hi-misses,hi,alpha)>=target: break
        if hi>200000: return None
    lo=misses+1
    while lo<hi:
        mid=(lo+hi)//2
        if cp_lower(mid-misses,mid,alpha)>=target: hi=mid
        else: lo=mid+1
    return lo

print("="*80)
print("A. INCLUDED STUDIES NEEDED IN THE VALIDATION SET, BY TARGET RECALL BOUND")
print("="*80)
for alpha,lab in [(0.025,"two-sided 95% CI (what your report quotes)"),(0.05,"one-sided 95%")]:
    print(f"\n-- {lab} --")
    print(f"{'recall lower bound':>20} | {'0 misses':>9} {'1 miss':>7} {'2 misses':>9} {'3 misses':>9}")
    print("-"*62)
    for t in [0.80,0.85,0.90,0.925,0.95,0.97,0.99]:
        row=[positives_needed(t,m,alpha) for m in range(4)]
        print(f"{t*100:>19.1f}% | {row[0]:>9} {row[1]:>7} {row[2]:>9} {row[3]:>9}")

print()
print("Your current position: 28/28 includes retained, 0 missed")
for a,lab in [(0.025,"two-sided 95% CI"),(0.05,"one-sided 95%")]:
    print(f"   {lab:>18}: recall lower bound = {cp_lower(28,28,a)*100:.1f}%")

print()
print("="*80)
print("B. TITLES YOU MUST MANUALLY SCREEN TO ACCUMULATE THOSE POSITIVES")
print("   Prevalence anchors from YOUR OWN review: 1,376 T/A records ->")
print("   273 advanced (19.8%) -> 21 included at full text (1.53%)")
print("="*80)
CORPUS=3000
print(f"\nCorpus = {CORPUS} title/abstracts. Ground truth = FINAL INCLUDE (the metric that matters).")
print(f"{'include rate':>13} {'total includes':>15} | {'>=90% bound':>12} {'>=95% bound':>12} {'>=97% bound':>12}")
print("-"*72)
for prev in [0.010,0.015,0.020,0.030,0.050]:
    tot=CORPUS*prev
    cells=[]
    for t in [0.90,0.95,0.97]:
        need=positives_needed(t,0,0.025)
        recs=need/prev
        cells.append(f"{recs:,.0f}" if recs<=CORPUS else "IMPOSSIBLE")
    print(f"{prev*100:>12.1f}% {tot:>15.0f} | {cells[0]:>12} {cells[1]:>12} {cells[2]:>12}")

print("\n('IMPOSSIBLE' = the whole corpus does not contain enough included studies,")
print(" even if you hand-screen all 3,000 and the AI misses nothing.)")

print()
print("-- Best bound obtainable by screening the ENTIRE corpus with a PERFECT AI --")
print(f"{'corpus':>8} {'include rate':>13} {'total includes':>15} {'max provable recall bound':>27}")
print("-"*68)
for corpus in [1376,3000,5000,10000]:
    for prev in [0.015,0.02,0.05]:
        k=int(round(corpus*prev))
        if k<1: continue
        print(f"{corpus:>8,} {prev*100:>12.1f}% {k:>15} {cp_lower(k,k,0.025)*100:>26.1f}%")

def hyper_p0(E,K,m):
    """P(0 includes drawn | pile E contains K includes, sample m)"""
    if K<0 or K>E or m>E: return 0.0
    if E-K<m: return 0.0
    return math.exp(lchoose(E-K,m)-lchoose(E,m))

def K_upper(E,m,alpha=0.05):
    """largest K consistent with observing 0 includes in m draws (95% upper bound)"""
    K=0
    while K<=E and hyper_p0(E,K,m)>=alpha: K+=1
    return max(0,K-1)

print()
print("="*80)
print("C. THE ACTIONABLE DESIGN: audit the AI's REJECT PILE, not a random sample")
print("   Corpus 3,000 | ~45 includes (1.5%) | AI rejects 65% => reject pile ~1,950")
print("="*80)
M,PREV=3000,0.015
TOT=round(M*PREV)
E=round(M*0.65)
FOUND=TOT  # assume AI advanced all real includes; we are bounding what's hidden
print(f"\nYou hand-screen m records drawn at random from the AI's reject pile (n={E}),")
print("and find zero includes among them. What can you then claim?\n")
print(f"{'m screened':>11} {'% of pile':>10} | {'<= this many includes hidden':>29} {'=> recall at least':>19}")
print("-"*76)
for m in [50,100,200,300,400,600,800,1000,1300,1600,1950]:
    if m>E: continue
    ku=K_upper(E,m)
    rec=FOUND/(FOUND+ku)*100
    print(f"{m:>11,} {m/E*100:>9.0f}% | {ku:>29} {rec:>18.1f}%")
print("\n(0 includes found is the BEST case. Find even one and every row gets worse.)")

print()
print("="*80)
print("D. WHAT 300 DUAL-SCREENED RECORDS ACTUALLY BUYS YOU ON A 3,000-RECORD REVIEW")
print("="*80)
for m,lab in [(300,"300 random from whole corpus"),(300,"300 random from reject pile")]:
    pass
exp_inc=300*PREV
print(f"\n300 records drawn at RANDOM from the whole corpus contain ~{exp_inc:.0f} includes.")
print(f"   If the AI retains all {exp_inc:.0f}: recall lower bound = {cp_lower(4,4,0.025)*100:.1f}%  (worthless)")
ku=K_upper(E,300)
print(f"\n300 records drawn from the AI's REJECT PILE, 0 includes found:")
print(f"   <= {ku} includes hidden in the pile => recall >= {TOT/(TOT+ku)*100:.1f}%")
print("   Same human effort, far more information. This is the design to use.")

print()
print("="*80)
print("E. THE REAL 'LEARNING CURVE': detecting a systematic rubric flaw")
print("   The model does not learn. The RUBRIC learns. A flaw is only fixable once seen.")
print("="*80)
print("\nA blind spot affecting fraction f of included studies (e.g. 'excludes papers")
print("that only report duration in a table'). How many INCLUDES must you eyeball")
print("before you have a 90% / 95% chance of catching it at least once?\n")
print(f"{'blind spot size f':>18} | {'includes to see (90%)':>22} {'includes to see (95%)':>22}")
print("-"*66)
for f in [0.50,0.30,0.20,0.10,0.05]:
    n90=math.ceil(math.log(0.10)/math.log(1-f))
    n95=math.ceil(math.log(0.05)/math.log(1-f))
    print(f"{f*100:>17.0f}% | {n90:>22} {n95:>22}")
print(f"\nAt a 1.5% include rate, seeing 20 includes means reading ~{20/0.015:,.0f} titles at random")
print(f"-- OR ~{20/0.145:,.0f} titles if you read the AI's ADVANCE pile, where includes concentrate.")

print()
print("="*80)
print("F. WHY THE UNION RULE MAKES THE WHOLE QUESTION GO AWAY")
print("="*80)
print("""
Union rule: advance if EITHER the human OR the AI advances.

  recall(union) = P(human advances OR AI advances)
                >= P(human advances)
                =  recall(human alone)

This is an identity, not an estimate. It holds for ANY AI recall, even 0%.
So the number of titles you must manually screen before the AI is 'safe to add'
is ZERO -- adding it cannot lower recall, only raise it.

Validation is therefore NOT a safety gate. It only answers a different question:
'may I now STOP paying a human?' -- and section C shows that costs ~1,300 of
1,950 reject-pile reads to reach a >=95% claim. At which point you saved little.
""")
