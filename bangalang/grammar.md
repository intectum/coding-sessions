$$
\begin{align}
program\ &\to\ statement*\\
statement\ &\to\ if\ |\ for\ |\ return\ |\ scope\ |\ assignment\ |\ rhs\_expression\\
if\ &\to\ \text{"if"}\ \text{"("}?\ rhs\_expression\ \text{")"}?\ statement\ (\ \text{"else"}\ \text{"if"}\ \text{"("}?\ rhs\_expression\ \text{")"}?\ statement\ )*\ (\ \text{"else"}\ statement\ )?\\
for\ &\to\ \text{"for"}\ \text{"("}?\ (\ statement\ \&\ !rhs\_expression\ \text{","}\ )?\ rhs\_expression\ (\ \text{","}\ statement\ )?\ \text{")"}?\ statement\\
scope\ &\to\ \text{"\{"}\ statement*\ \text{"\}"}\\
return\ &\to\ \text{"return"}\ rhs\_expression\\
assignment\ &\to\ lhs\_expression\ (\ (\ \text{"="}\ |\ \text{"+="}\ |\ \text{"-="}\ |\ \text{"*="}\ |\ \text{"/="}\ |\ \text{"%="}\ )\ statement\ )?\\
lhs\_expression\ &\to\ lhs\_primary\ (\ \text{":"}\ type\_primary\ )?\\
lhs\_primary\ &\to\ lhs\_primary\ (\ \text{"^"}\ |\ \text{"["}\ rhs\_expression\ (\ \text{":"}\ rhs\_expression\ )?\ \text{"]"}\ |\ \text{"."}\ lhs\_primary\ )\ |\ identifier\\
rhs\_expression\ &\to\ rhs\_primary\ (\ (\ \text{"||"}\ |\ \text{"%%"}\ |\ \text{"=="}\ |\ \text{"!="}\ |\ \text{"<"}\ |\ \text{">"}\ |\ \text{"<="}\ |\ \text{">="}\ |\ \text{"+"}\ |\ \text{"-"}\ |\ \text{"*"}\ |\ \text{"/"}\ |\ \text{"%"}\ )\ rhs\_primary\ )*\\
rhs\_primary\ &\to\ (\ directive\ |\ \text{"^"}\ |\ \text{"-"}\ |\ \text{"!"}\ )\ rhs\_primary\ |\ rhs\_primary\ (\ \text{"^"}\ |\ \text{"["}\ (\ rhs\_expression\ |\ rhs\_expression?\ \text{":"}\ rhs\_expression?\ )\ \text{"]"}\ |\ \text{"."}\ rhs\_primary\ |\ call\ )\ |\ \text{"("}\ rhs\_expression\ \text{")"}\ |\ identifier\ |\ struct\_type\ |\ procedure\_type\ |\ boolean\_literal\ |\ number\_literal\ |\ string\_literal\ |\ compound\_literal\ |\ \text{"nil"}\\
type\_primary\ &\to\ (\ directive\ |\ \text{"^"}\ )\ type\_primary\ |\ type\_primary\ (\ \text{"["}\ number?\ \text{"]"}\ |\ \text{"."}\ type\_primary\ )\ |\ identifier\ |\ struct\_type\ |\ procedure\_type\\
call\ &\to\ \text{"("}\ (\ rhs\_expression\ (\ \text{","}\ rhs\_expression\ )*\ )?\ \text{")"}\\
boolean\_literal\ &\to\ \text{"false"}\ |\ \text{"true"}\\
number\_literal\ &\to\ \text{'-'}?\ digit+\ (\ \text{'.'}\ digit*\ )?\\
string\_literal\ &\to\ \text{'"'}\ (\ !\text{'"'}\ )*\ \text{'"'}\\
compound\_literal\ &\to\ \text{"\{"}\ (\ assignment\ (\ \text{","}\ assignment\ )*\ )?\ \text{"\}"}\\
struct\_type\ &\to\ \text{"struct"}\ \text{"\{"}\ (\ identifier\ \text{":"}\ type\_primary\ (\ \text{","}\ identifier\ \text{":"}\ type\_primary\ )*\ )?\ \text{"\}"}\\
procedure\_type\ &\to\ \text{"proc"}\ \text{"("}\ (\ identifier\ \text{":"}\ type\_primary\ (\ \text{","}\ identifier\ \text{":"}\ type\_primary\ )*\ )?\ \text{")"}\ (\ \text{"->"}\ type\_primary\ )?\\
digit\ &\to\ \text{'0'}\ |\ \text{'1'}\ |\ \text{'2'}\ |\ \text{'3'}\ |\ \text{'4'}\ |\ \text{'5'}\ |\ \text{'6'}\ |\ \text{'7'}\ |\ \text{'8'}\ |\ \text{'9'}\\
\end{align}
$$
