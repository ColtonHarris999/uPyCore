# The friendly REPL on the UART console (+REPL, +CONSOLE=uart) after
# __main__: an expression, a compound statement ended by an empty line,
# _, a traceback, Ctrl-C dropping a line, and Ctrl-B's banner. The REPL
# then waits for input, so the run ends at its cycle limit.
print('main ran')
x = 5
