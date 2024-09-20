1. 行内公式，比如 $E = mc^2$

2. 块级公式: 
            $$
            a^2 + b^2 = c^2
            $$

3. 常见的 LaTeX 语法
    乘积：$ x \times y = k $
    分数：$ \frac{a}{b} $
    开平方：$ \sqrt{x} $
    求和：$ \sum_{i=1}^{n} i^2 $
    积分：$ \int_0^1 x^2 dx $
    小空格：\,  \:  \;
    中空格：\quad
    大空格：\qquad

<hr />

1. UniSwap V2 中添加流动性、移除流动性：
只需要按照 pool 中两种代币 x，y 的储量的比例进行计算即可。
$$
    \frac{x}{y} = \frac{\Delta x}{\Delta y}
$$

<br />

2. UniSwap V2 中进行 swap 交换：
基本原理： $ x \times y = k $
下面公式，假设投入 $\Delta x$，取出 $\Delta y$。
x -->  inputReserve    
$$
    (x + \Delta x)(y - \Delta y) = x \times y
$$
$$
    \Delta x = x \times \frac{ \Delta y }{ y - \Delta y} \qquad \Delta y = y \times \frac{ \Delta x }{ x + \Delta x}
$$

<br />

3. UniSwap V2中的无常损失：
