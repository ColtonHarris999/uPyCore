exec(compile("print(1 + 2)", "<s>", "exec"))
print(eval(compile("1 + 2 * 3", "<s>", "eval")))
exec("a = 4\nprint(a + 1)")
