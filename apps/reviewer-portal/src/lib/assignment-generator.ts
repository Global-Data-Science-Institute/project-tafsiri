export type Item={id:string;sampling_group:string;bucket:"A"|"B"|"C"};
export type Reviewer={id:string;code:string};
export type Assignment={itemId:string;reviewerId:string};
function rng(seed:number){return()=>{seed=(seed*1664525+1013904223)>>>0;return seed/4294967296}}
export function generateAssignments(items:Item[],reviewers:Reviewer[],target=3,seed=20260813){
 if(reviewers.length<target) throw new Error("Not enough eligible reviewers"); const random=rng(seed), loads=new Map(reviewers.map(r=>[r.id,0]));
 const pairs=new Map<string,number>(), strata=new Map<string,Map<string,number>>(); const out:Assignment[]=[];
 const ordered=[...items].map(x=>({x,k:random()})).sort((a,b)=>a.x.sampling_group.localeCompare(b.x.sampling_group)||a.x.bucket.localeCompare(b.x.bucket)||a.k-b.k);
 for(const {x} of ordered){const chosen:Reviewer[]=[];for(let n=0;n<target;n++){const candidates=reviewers.filter(r=>!chosen.includes(r)).map(r=>{const s=strata.get(r.id)??new Map();const pair=chosen.reduce((v,c)=>v+(pairs.get([r.id,c.id].sort().join("|"))??0),0);return{r,score:[loads.get(r.id)!,s.get(`${x.sampling_group}|${x.bucket}`)??0,pair,random()] as number[]}}).sort((a,b)=>a.score.findIndex((v,i)=>v!==b.score[i])<0?0:(()=>{for(let i=0;i<a.score.length;i++)if(a.score[i]!==b.score[i])return a.score[i]-b.score[i];return 0})());chosen.push(candidates[0].r)}
  for(const r of chosen){out.push({itemId:x.id,reviewerId:r.id});loads.set(r.id,loads.get(r.id)!+1);const s=strata.get(r.id)??new Map();s.set(`${x.sampling_group}|${x.bucket}`,(s.get(`${x.sampling_group}|${x.bucket}`)??0)+1);strata.set(r.id,s);for(const c of chosen)if(c!==r){const k=[r.id,c.id].sort().join("|");pairs.set(k,(pairs.get(k)??0)+.5)}}}
 return out;
}
export function validateAssignments(items:Item[],reviewers:Reviewer[],assignments:Assignment[],target=3){const duplicates=new Set<string>();let dup=false;for(const a of assignments){const k=`${a.itemId}|${a.reviewerId}`;if(duplicates.has(k))dup=true;duplicates.add(k)}const coverage=items.every(i=>assignments.filter(a=>a.itemId===i.id).length===target);const loads=reviewers.map(r=>assignments.filter(a=>a.reviewerId===r.id).length);return{valid:!dup&&coverage,duplicates:dup,coverage,loads,total:assignments.length};}
