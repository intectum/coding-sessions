$$
\begin{align}
program\ &\to\ statement*\\
statement\ &\to\ if\ |\ for\ |\ scope\ |\ return\ |\ assignment\ |\ rhs\_expression\\
if\ &\to\ \text{"if"}\ \text{"("}\ rhs\_expression\ \text{")"}\ statement\ (\ \text{"else"}\ \text{"if"}\ \text{"("}\ rhs\_expression\ \text{")"}\ statement\ )*\ (\ \text{"else"}\ statement\ )?\\
for\ &\to\ \text{"for"}\ \text{"("}\ (\ assignment\ \text{","}\ )?\ rhs\_expression\ (\ \text{","}\ assignment\ )?\ \text{")"}\ statement\\
scope\ &\to\ \text{"\{"}\ statement*\ \text{"\}"}\\
return\ &\to\ \text{"return"}\ rhs\_expression\\
assignment\ &\to\ lhs\_expression\ (\ \text{"="}\ statement\ )?\\
lhs\_expression\ &\to\ lhs\_primary\ (\ \text{":"}\ type\ )?\\
lhs\_primary\ &\to\ lhs\_primary\ (\ \text{"^"}\ |\ \text{"["}\ rhs\_expression\ \text{"]"}\ |\ \text{"."}\ lhs\_primary\ )\ |\ identifier\\
rhs\_expression\ &\to\ rhs\_primary\ (\ (\ \text{"=="}\ |\ \text{"!="}\ |\ \text{"<"}\ |\ \text{">"}\ |\ \text{"<="}\ |\ \text{">="}\ |\ \text{"+"}\ |\ \text{"-"}\ |\ \text{"*"}\ |\ \text{"/"}\ |\ \text{"%"}\ )\ rhs\_primary\ )*\\
rhs\_primary\ &\to\ (\ \text{"#untyped"}\ |\ \text{"^"}\ |\ \text{"-"}\ )\ rhs\_primary\ |\ rhs\_primary\ (\ \text{"^"}\ |\ \text{"["}\ rhs\_expression\ \text{"]"}\ |\ \text{"."}\ rhs\_primary\ )\ |\ \text{"("}\ rhs\_expression\ \text{")"}\ |\ call\ |\ identifier\ |\ string\ |\ cstring\ |\ number\ |\ boolean\ |\ \text{"nil"}\\
call\ &\to\ identifier\ \text{"("}\ (\ rhs\_expression\ (\ \text{","}\ rhs\_expression\ )*\ )?\ \text{")"}\\
string\ &\to\ \text{"""}\ (\ !\text{"""}\ )*\ \text{"""}\\
cstring\ &\to\ \text{"c""}\ (\ !\text{"""}\ )*\ \text{"""}\\
number\ &\to\ digit+\ (\ \text{"."}\ digit*\ )?\\
boolean\ &\to\ \text{"false"}\ |\ \text{"true"}\\
type\ &\to\ directive?\ \text{"^"}?\ data\_type\ (\ \text{"["}\ number\ \text{"]"}\ )?\\
data\_type\ &\to\ struct\_type\ |\ procedure\_type\ |\ \text{"bool"}\ |\ \text{"cint"}\ |\ \text{"cstring"}\ |\ \text{"f32"}\ |\ \text{"f64"}\ |\ \text{"i8"}\ |\ \text{"i16"}\ |\ \text{"i32"}\ |\ \text{"i64"}\ |\ \text{"string"}\\
struct\_type\ &\to\ \text{"struct"}\ \text{"\{"}\ (\ identifier\ \text{":"}\ type\ )*\ \text{"\}"}\\
procedure\_type\ &\to\ \text{"proc"}\ \text{"("}\ (\ identifier\ \text{":"}\ type\ (\ \text{","}\ identifier\ \text{":"}\ type\ )*\ )?\ \text{")"}\ (\ \text{"->"}\ type\ )?\\
digit\ &\to\ \text{"0"}\ |\ \text{"1"}\ |\ \text{"2"}\ |\ \text{"3"}\ |\ \text{"4"}\ |\ \text{"5"}\ |\ \text{"6"}\ |\ \text{"7"}\ |\ \text{"8"}\ |\ \text{"9"}\\
\end{align}
$$
