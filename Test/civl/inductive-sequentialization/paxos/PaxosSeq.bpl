procedure {:atomic}{:layer 3} A_Paxos'({:linear_in "perm"} rs: [Round]bool)
returns ()
modifies joinedNodes, voteInfo, decision, pendingAsyncs;
{
  assert Init(rs, joinedNodes, voteInfo, decision, pendingAsyncs);
  havoc joinedNodes, voteInfo, decision, pendingAsyncs;
  assume (forall r1: Round, r2: Round :: is#Some(decision[r1]) && is#Some(decision[r2]) ==> decision[r1] == decision[r2]);
}

procedure {:atomic}{:layer 2}
{:IS "A_Paxos'","INV"}
{:elim "A_StartRound","A_StartRound'"}
{:elim "A_Propose","A_Propose'"}
{:elim "A_Conclude","A_Conclude'"}
{:elim "A_Join","A_Join'"}
{:elim "A_Vote","A_Vote'"}
A_Paxos({:linear_in "perm"} rs: [Round]bool)
returns ({:pending_async "A_StartRound"} PAs:[PA]int)
modifies pendingAsyncs;
{
  var {:pool "NumRounds"} numRounds: int;
  assert
    Init(rs, joinedNodes, voteInfo, decision, pendingAsyncs);
  assume
    {:add_to_pool "Round", 0, numRounds}
    {:add_to_pool "NumRounds", numRounds}
    0 <= numRounds;
  PAs := (lambda pa: PA :: if is#A_StartRound(pa) && round#A_StartRound(pa) == round_lin#A_StartRound(pa) && Round(round#A_StartRound(pa)) && round#A_StartRound(pa) <= numRounds then 1 else 0);
  pendingAsyncs := PAs;
}

function {:inline} StartRoundPAs(k: int, numRounds: int) : [PA]int
{
  (lambda pa: PA :: if (is#A_StartRound(pa) && round#A_StartRound(pa) == round_lin#A_StartRound(pa) && k < round#A_StartRound(pa) && round#A_StartRound(pa) <= numRounds) then 1 else 0)
}

function {:inline} StartRoundPlusJoinPlusProposePAs(k: int, m: Node, numRounds: int) : [PA]int
{
  (lambda pa : PA ::
    if (is#A_StartRound(pa) && round#A_StartRound(pa) == round_lin#A_StartRound(pa) && k+1 < round#A_StartRound(pa) && round#A_StartRound(pa) <= numRounds) ||
       (pa == A_Propose(k+1, ProposePermissions(k+1))) ||
       (is#A_Join(pa) && round#A_Join(pa) == k+1 && m < node#A_Join(pa) && node#A_Join(pa) <= numNodes &&
         p#A_Join(pa) == JoinPerm(k+1, node#A_Join(pa)))
    then 1 else 0)
}

function {:inline} JoinOrProposeChoice(k: int, m: Node) : PA
{
  if m == numNodes then A_Propose(k+1, ProposePermissions(k+1)) else A_Join(k+1, m+1, JoinPerm(k+1, m+1))
}

function {:inline} StartRoundPlusVotePlusConcludePAs(k: int, m: Node, v: Value, numRounds: int) : [PA]int
{
  ( lambda pa: PA ::
    if (is#A_StartRound(pa) && round#A_StartRound(pa) == round_lin#A_StartRound(pa) && k+1 < round#A_StartRound(pa) && round#A_StartRound(pa) <= numRounds) ||
       (pa == A_Conclude(k+1, v, ConcludePerm(k+1))) ||
       (is#A_Vote(pa) && round#A_Vote(pa) == k+1 && m < node#A_Vote(pa) && node#A_Vote(pa) <= numNodes &&
         value#A_Vote(pa) == v && p#A_Vote(pa) == VotePerm(k+1, node#A_Vote(pa)))
    then 1 else 0)
}

function {:inline} VoteOrConcludeChoice(k: int, m: Node, v: Value) : PA
{
  if m == numNodes then A_Conclude(k+1, v, ConcludePerm(k+1)) else A_Vote(k+1, m+1, v, VotePerm(k+1, m+1))
}

procedure {:IS_invariant}{:layer 2} INV({:linear_in "perm"} rs: [Round]bool)
returns ({:pending_async "A_StartRound","A_Propose","A_Conclude","A_Join","A_Vote"} PAs:[PA]int, {:choice} choice:PA)
modifies joinedNodes, voteInfo, decision, pendingAsyncs;
{
  var {:pool "NumRounds"} numRounds: int;
  var {:pool "Round"} k: int;
  var {:pool "Node"} m: Node;

  assert Init(rs, joinedNodes, voteInfo, decision, pendingAsyncs);

  havoc joinedNodes, voteInfo, decision;

  // This invariant is the "pending async skeleton" which states the possible
  // pending asyncs in the sequentialization. The existentially quantified k
  // denotes the number of rounds that already finished (i.e., rounds 1 to k
  // finished and k+1 is the round that currently executes), and similarly the
  // existentially quantified m denotes the number of nodes that already
  // finished in the current round.

  assume
    {:add_to_pool "NumRounds", numRounds}
    {:add_to_pool "Round", k, k+1, numRounds}
    0 <= k && k <= numRounds;

  if (k == numRounds) {
      PAs := NoPAs();
  } else if (*) {
      assume
        (forall r: Round :: r < 1 || r > k ==> is#None(voteInfo[r])) &&
        (forall r: Round :: r < 1 || r > k ==> is#None(decision[r]));
      PAs := StartRoundPAs(k, numRounds);
      choice := A_StartRound(k+1, k+1);
  } else if (*) {
      assume
        (forall r: Round :: r < 1 || r > k ==> is#None(voteInfo[r])) &&
        (forall r: Round :: r < 1 || r > k ==> is#None(decision[r]));
      assume
        {:add_to_pool "Node", m}
        0 <= m && m <= numNodes;
      PAs := StartRoundPlusJoinPlusProposePAs(k, m, numRounds);
      choice := JoinOrProposeChoice(k, m);
  } else {
      assume
        is#Some(voteInfo[k+1]) &&
        (forall r: Round :: r < 1 || r > k+1 ==> is#None(voteInfo[r])) &&
        (forall r: Round :: r < 1 || r > k ==> is#None(decision[r]));
      assume
        {:add_to_pool "Node", m}
        0 <= m && m <= numNodes &&
        (forall n: Node :: n < 1 || n > m ==> !ns#VoteInfo(t#Some(voteInfo[k+1]))[n]);
      PAs := StartRoundPlusVotePlusConcludePAs(k, m, value#VoteInfo(t#Some(voteInfo[k+1])), numRounds);
      choice := VoteOrConcludeChoice(k, m, value#VoteInfo(t#Some(voteInfo[k+1])));
  }

  // If there was a decision for some value, then there must have been a
  // proposal of the same value and a quorum of nodes that voted for it.
  assume (forall r: Round :: is#Some(decision[r]) ==>
    is#Some(voteInfo[r]) &&
    value#VoteInfo(t#Some(voteInfo[r])) == t#Some(decision[r]) &&
    (exists q: NodeSet ::
      IsSubset(q, ns#VoteInfo(t#Some(voteInfo[r]))) && IsQuorum(q)));

  // This is the main invariant to prove
  assume (forall r1: Round, r2: Round :: is#Some(decision[r1]) && r1 <= r2 && is#Some(voteInfo[r2]) ==> value#VoteInfo(t#Some(voteInfo[r2])) == t#Some(decision[r1]));

  // This is the main property to prove
  assume (forall r1: Round, r2: Round :: is#Some(decision[r1]) && is#Some(decision[r2]) ==> decision[r1] == decision[r2]);

  pendingAsyncs := PAs;
}

// Local Variables:
// flycheck-disabled-checkers: (boogie)
// End:
