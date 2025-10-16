$$
\begin{align}
module\ &\to\ statements\\
statements\ &\to\ statement*\\
statement\ &\to\ if\_statement\ |\ for\_statement\ |\ switch\_statement\ |\ continue\_statement\ |\ break\_statement\ |\ return\_statement\ |\ scope\_statement\ |\ assignment\_statement\ |\ rhs\_expression\\
if\_statement\ &\to\ \text{"if"}\ \text{"("}?\ rhs\_expression\ \text{")"}?\ statement\ (\ \text{"else"}\ \text{"if"}\ \text{"("}?\ rhs\_expression\ \text{")"}?\ statement\ )*\ (\ \text{"else"}\ statement\ )?\\
for\_statement\ &\to\ \text{"for"}\ \text{"("}?\ (\ declaration\_statement\ \text{","}\ )?\ rhs\_expression\ (\ \text{","}\ assignment\_statement\ )?\ \text{")"}?\ statement\\
switch\_statement\ &\to\ \text{"switch"}\ rhs\_expression\ \text{"\{"}\ (\ (\ rhs\_expression\ |\ \text{"default"}\ )\ \text{":"}\ statement\ )*\ \text{"\}"}\ \\
continue\_statement\ &\to\ \text{"continue"}\\
break\_statement\ &\to\ \text{"break"}\\
return\_statement\ &\to\ \text{"return"}\ rhs\_expression?\\
scope\_statement\ &\to\ \text{"\{"}\ statements\ \text{"\}"}\\
assignment\_statement\ &\to\ lhs\_expression\ (\ (\ \text{"="}\ |\ \text{"|="}\ |\ \text{"&="}\ |\ \text{"+="}\ |\ \text{"-="}\ |\ \text{"*="}\ |\ \text{"/="}\ |\ \text{"%="}\ )\ statement\ )?\\
simple\_assignment\_statement\ &\to\ identifier\ \text{"="}\ statement\\
lhs\_expression\ &\to\ lhs\_declaration\ |\ lhs\_primary\\
declaration\_statement\ &\to\ lhs\_declaration\ (\ \text{"="}\ statement\ )?\\
lhs\_declaration\ &\to\ identifier\ \text{":"}\ type\_primary?\ (\ \text{"@"}\ identifier\ )?\\
lhs\_primary\ &\to\ lhs\_primary\ (\ \text{"^"}\ |\ \text{"["}\ rhs\_expression\ (\ \text{":"}\ rhs\_expression\ )?\ \text{"]"}\ |\ \text{"."}\ lhs\_primary\ )\ |\ \text{"("}\ lhs\_primary\ \text{")"}\ |\ identifier\\
rhs\_expression\ &\to\ rhs\_primary\ (\ (\ \text{"|"}\ |\ \text{"||"}\ |\ \text{"&"}\ |\ \text{"&&"}\ |\ \text{"=="}\ |\ \text{"!="}\ |\ \text{"<"}\ |\ \text{">"}\ |\ \text{"<="}\ |\ \text{">="}\ |\ \text{"+"}\ |\ \text{"-"}\ |\ \text{"*"}\ |\ \text{"/"}\ |\ \text{"%"}\ )\ rhs\_primary\ )*\\
rhs\_primary\ &\to\ (\ directive\ |\ \text{"^"}\ |\ \text{"-"}\ |\ \text{"!"}\ )\ rhs\_primary\ |\ rhs\_primary\ (\ \text{"^"}\ |\ \text{"["}\ (\ rhs\_expression\ |\ rhs\_expression\ \text{":"}\ |\ \text{":"}\ rhs\_expression\ |\ rhs\_expression\ \text{":"}\ rhs\_expression\ )?\ \text{"]"}\ |\ \text{"."}\ rhs\_primary\ |\ call\ )\ |\ \text{"("}\ rhs\_expression\ \text{")"}\ |\ identifier\ |\ struct\_type\ |\ procedure\_type\ |\ boolean\_literal\ |\ number\_literal\ |\ string\_literal\ |\ compound\_literal\ |\ nil\_literal\\
type\_primary\ &\to\ (\ directive\ |\ \text{"^"}\ )\ type\_primary\ |\ type\_primary\ (\ \text{"["}\ number?\ \text{"]"}\ |\ \text{"."}\ type\_primary\ )\ |\ \text{"("}\ type\_primary\ \text{")"}\ |\ identifier\ |\ struct\_type\ |\ procedure\_type\\
call\ &\to\ \text{"("}\ (\ rhs\_expression\ (\ \text{","}\ rhs\_expression\ )*\ )?\ \text{")"}\\
boolean\_literal\ &\to\ \text{"false"}\ |\ \text{"true"}\\
number\_literal\ &\to\ \text{'-'}?\ digit+\ (\ \text{'.'}\ digit*\ )?\\
string\_literal\ &\to\ \text{'"'}\ (\ !\text{'"'}\ )*\ \text{'"'}\\
compound\_literal\ &\to\ \text{"\{"}\ (\ (\ simple\_assignment\_statement\ (\ \text{","}\ simple\_assignment\_statement\ )*\ )?\ |\ (\ rhs\_expression\ (\ \text{","}\ rhs\_expression\ )*\ )?\ )\ \text{"\}"}\\
nil\_literal\ &\to\ \text{"nil"}\\
struct\_type\ &\to\ \text{"struct"}\ \text{"\{"}\ (\ identifier\ \text{":"}\ type\_primary\ (\ \text{","}\ identifier\ \text{":"}\ type\_primary\ )*\ )?\ \text{"\}"}\\
procedure\_type\ &\to\ \text{"proc"}\ \text{"("}\ (\ declaration\_statement\ (\ \text{","}\ declaration\_statement\ )*\ )?\ \text{")"}\ (\ \text{"->"}\ type\_primary\ )?\\
digit\ &\to\ \text{'0'}\ |\ \text{'1'}\ |\ \text{'2'}\ |\ \text{'3'}\ |\ \text{'4'}\ |\ \text{'5'}\ |\ \text{'6'}\ |\ \text{'7'}\ |\ \text{'8'}\ |\ \text{'9'}\\
\end{align}
$$
