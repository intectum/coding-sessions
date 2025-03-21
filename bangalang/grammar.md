$$
\begin{align}
program\ &\to\ (\ procedure\ |\ statement\ )^*\\
procedure\ &\to\ identifier\ \text{":"}\ \text{"="}\ \text{"proc"}\ \text{"("}\ (\ identifier\ \text{":"}\ type\ (\ \text{","}\ identifier\ \text{":"}\ type\ )^*\ )?\ \text{")"}\ \text{"->"}\ type\ scope\\
statement\ &\to\ if\ |\ scope\ |\ declaration\ |\ assignment\ |\ return\ |\ call \\
if\ &\to\ \text{"if"}\ expression\ scope\ (\ \text{"else"}\ \text{"if"}\ expression\ scope\ )^*\ (\ \text{"else"}\ scope\ )?\\
for\ &\to\ \text{"for"}\ (\ expression\ |\ declaration\ \text{","}\ expression\ \text{","}\ assignment\ )\ scope\\
scope\ &\to\ \text{"\{"}\ statement^*\ \text{"\}"}\\
declaration\ &\to\ identifier\ \text{":"}\ type?\ (\ \text{"="}\ expression\ )?\\
assignment\ &\to\ variable\ \text{"="}\ expression\\
return\ &\to\ \text{"return"}\ expression\\
expression\ &\to\ primary\ (\ (\ \text{"+"}\ |\ \text{"-"}\ |\ \text{"*"}\ |\ \text{"/"}\ )\ primary\ )^*\\
primary\ &\to\ \text{"("}\ expression\ \text{")"}\ |\ call\ |\ variable\ |\ number\ |\ \text{"-"}\ primary\\
call\ &\to\ identifier\ \text{"("}\ (\ expression\ (\ \text{","}\ expression\ )^*\ )?\ \text{")"}\\
variable\ &\to\ identifier\ (\ \text{"["}\ number\ \text{"]"}\ )?\\
type\ &\to\ data\_type\ (\ \text{"["}\ number\ \text{"]"}\ )?\\
data\_type\ &\to\ \text{"i8"}\ |\ \text{"i16"}\ |\ \text{"i32"}\ |\ \text{"i64"}\\
\end{align}
$$
