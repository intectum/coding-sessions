$$
\begin{align}
  [\text{Program}] &\to [\text{Statement}]^* \\
  [\text{Statement}] &\to
  \begin{cases}
    [\text{Scope}] \\
    \text{identifier} = [\text{Term}] \\
    \text{exit}([\text{Term}]) \\
  \end{cases} \\
  [\text{Scope}] &\to \{[\text{Statement}]^*\} \\
  [\text{Term}] &\to
  \begin{cases}
    \text{identifier} \\
    \text{integer literal} \\
  \end{cases}
\end{align}
$$
