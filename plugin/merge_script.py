import re, vim
base = open(vim.eval("a:base"))
patch = vim.eval("a:patch")
with open(patch) as f:
    lines = f.readlines()

p = re.compile(r"^(\d+)(?:,(\d+))?[cd]")
filepointer = 1
i = 0
while i < len(lines):
    m = p.match(lines[i])
    i += 1
    if m:
        start, finish = m.groups()
        if finish is None:
            finish = start
        start, finish = map(int, (start, finish))
        while start <= finish:
            while filepointer < start:
                base.readline()
                filepointer += 1
            lines[i] = "< " + base.readline()
            if not lines[i].endswith("\n"):
                lines[i] += "\n"
            i += 1
            start += 1
            filepointer += 1
with open(patch, 'w') as f:
    f.writelines(lines)
