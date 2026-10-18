try:
    compile("def (", "<f>", "exec")
    print("accepted")
except SyntaxError as e:
    print(type(e).__name__)
    print(e)
except Exception as e:
    print(type(e).__name__)
    print(e)
