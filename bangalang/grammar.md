$$
\begin{align}
program\ &\to\ (\ procedure\ |\ statement\ )^*\\
procedure\ &\to\ identifier\ \text{":"}\ \text{"="}\ \text{"proc"}\ \text{"("}\ (\ identifier\ \text{":"}\ type\ (\ \text{","}\ identifier\ \text{":"}\ type\ )^*\ )?\ \text{")"}\ \text{"->"}\ type\ statement\\
statement\ &\to\ if\ |\ for\ |\ scope\ |\ declaration\ |\ assignment\ |\ return\ |\ call \\
if\ &\to\ \text{"if"}\ \text{"("}\ expression\ \text{")"}\ statement\ (\ \text{"else"}\ \text{"if"}\ \text{"("}\ expression\ \text{")"}\ statement\ )^*\ (\ \text{"else"}\ statement\ )?\\
for\ &\to\ \text{"for"}\ \text{"("}\ (\ declaration\ \text{","}\ )?\ expression\ (\ \text{","}\ assignment\ )?\ \text{")"}\ statement\\
scope\ &\to\ \text{"\{"}\ statement^*\ \text{"\}"}\\
declaration\ &\to\ identifier\ \text{":"}\ type?\ (\ \text{"="}\ expression\ )?\\
assignment\ &\to\ variable\ \text{"="}\ expression\\
return\ &\to\ \text{"return"}\ expression\\
expression\ &\to\ primary\ (\ (\ \text{"=="}\ |\ \text{"!="}\ |\ \text{"<"}\ |\ \text{">"}\ |\ \text{"<="}\ |\ \text{">="}\ |\ \text{"+"}\ |\ \text{"-"}\ |\ \text{"*"}\ |\ \text{"/"}\ )\ primary\ )^*\\
primary\ &\to\ (\ \text{"^"}\ |\ \text{"-"}\ )\ primary\ |\ primary\ (\ \text{"^"}\ |\ \text{"["}\ number\ \text{"]"}\ )\ |\ \text{"("}\ expression\ \text{")"}\ |\ call\ |\ identifier\ |\ string\ |\ cstring\ |\ number\ |\ boolean\\
call\ &\to\ identifier\ \text{"("}\ (\ expression\ (\ \text{","}\ expression\ )^*\ )?\ \text{")"}\\
variable\ &\to\ identifier\ (\ \text{"["}\ number\ \text{"]"}\ )?\\
string\ &\to\ \text{"""}\ (\ !\text{"""}\ )^*\ \text{"""}\\\
cstring\ &\to\ \text{"c""}\ (\ !\text{"""}\ )^*\ \text{"""}\\\
number\ &\to\ (\ \text{"0"}\ |\ \text{"1"}\ |\ \text{"2"}\ |\ \text{"3"}\ |\ \text{"4"}\ |\ \text{"5"}\ |\ \text{"6"}\ |\ \text{"7"}\ |\ \text{"8"}\ |\ \text{"9"}\ )+\\
boolean\ &\to\ \text{"false"}\ |\ \text{"true"}\\
type\ &\to\ \text{"^"}?\ data\_type\ (\ \text{"["}\ number\ \text{"]"}\ )?\\
data\_type\ &\to\ \text{"bool"}\ |\ \text{"i8"}\ |\ \text{"i16"}\ |\ \text{"i32"}\ |\ \text{"i64"}\ |\ \text{"string"}\\
\end{align}
$$
