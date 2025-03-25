$$
\begin{align}
program\ &\to\ (\ procedure\ |\ statement\ )^*\\
procedure\ &\to\ identifier\ \text{":"}\ \text{"="}\ \text{"proc"}\ \text{"("}\ (\ identifier\ \text{":"}\ type\ (\ \text{","}\ identifier\ \text{":"}\ type\ )^*\ )?\ \text{")"}\ \text{"->"}\ type\ scope\\
statement\ &\to\ if\ |\ for\ |\ scope\ |\ declaration\ |\ assignment\ |\ return\ |\ call \\
if\ &\to\ \text{"if"}\ expression\ scope\ (\ \text{"else"}\ \text{"if"}\ expression\ scope\ )^*\ (\ \text{"else"}\ scope\ )?\\
for\ &\to\ \text{"for"}\ (\ expression\ |\ declaration\ \text{","}\ expression\ \text{","}\ assignment\ )\ scope\\
scope\ &\to\ \text{"\{"}\ statement^*\ \text{"\}"}\\
declaration\ &\to\ identifier\ \text{":"}\ type?\ (\ \text{"="}\ expression\ )?\\
assignment\ &\to\ variable\ \text{"="}\ expression\\
return\ &\to\ \text{"return"}\ expression\\
expression\ &\to\ primary\ (\ (\ \text{"+"}\ |\ \text{"-"}\ |\ \text{"*"}\ |\ \text{"/"}\ )\ primary\ )^*\\
primary\ &\to\ (\ \text{"^"}\ |\ \text{"-"}\ )\ primary\ |\ primary\ (\ \text{"^"}\ |\ \text{"["}\ number\ \text{"]"}\ )\ |\ \text{"("}\ expression\ \text{")"}\ |\ call\ |\ identifier\ |\ number\ |\ boolean\\
call\ &\to\ identifier\ \text{"("}\ (\ expression\ (\ \text{","}\ expression\ )^*\ )?\ \text{")"}\\
variable\ &\to\ identifier\ (\ \text{"["}\ number\ \text{"]"}\ )?\\
number\ &\to\ (\ \text{"0"}\ |\ \text{"1"}\ |\ \text{"2"}\ |\ \text{"3"}\ |\ \text{"4"}\ |\ \text{"5"}\ |\ \text{"6"}\ |\ \text{"7"}\ |\ \text{"8"}\ |\ \text{"9"}\ )+\\
boolean\ &\to\ \text{"false"}\ |\ \text{"true"}\\
type\ &\to\ \text{"^"}?\ data\_type\ (\ \text{"["}\ number\ \text{"]"}\ )?\\
data\_type\ &\to\ \text{"bool"}\ |\ \text{"i8"}\ |\ \text{"i16"}\ |\ \text{"i32"}\ |\ \text{"i64"}\\
\end{align}
$$
