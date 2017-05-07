au BufNewFile *.ecfg.yaml call EcfgCreate("yaml")
au BufNewFile *.ecfg.json call EcfgCreate("json")
au BufWriteCmd,FileWriteCmd *.ecfg.yaml call EcfgWriteCmd("yaml")
au BufWriteCmd,FileWriteCmd *.ecfg.toml call EcfgWriteCmd("toml")
au BufWriteCmd,FileWriteCmd *.ecfg.json call EcfgWriteCmd("json")

function! EcfgCreate(type)
    let l:choice = confirm("Generate a new keypair for this file?", "&Yes\n&No\n&Choose one at random")
    if l:choice == 1
        let l:pubkey = system("ecfg keygen -w 2>/dev/null | xargs -n1 printf %s")
    elseif l:choice == 3
        let l:pubkey = system("ls ~/.ecfg/keys | sort -r | head -n1 | xargs -n1 printf %s")
    else
        let l:pubkey = ""
    endif
    if a:type ==? "yaml"
        call append(0, ["---", "_public_key: ".l:pubkey])
        3d
        normal $
    elseif a:type ==? "json"
        call append(0, ["{", '  "_public_key": "'.l:pubkey.'"', "}"])
        4d
        normal 2G$
    endif
endfunction

function! EcfgWriteDirect(type)
    let nm = expand("<afile>")
    let tmp = tempname()
    silent exe "noautocmd w !ecfg encrypt --type ".a:type." 2>&1 > ".tmp
    if !v:shell_error
        call rename(tmp, nm)
        setlocal nomodified
    else
        echohl ErrorMsg
        redraw
        echo "An error occured while trying to encrypt the file."
        echohl NONE
        call delete(tmp)
    endif
endfunction


if has("python")
    au BufReadPost,FileReadPost *.ecfg.yaml,*.ecfg.toml,*.ecfg.json call EcfgReadCmd(expand("<afile>"))

    function! PyMerge(base, patch)
python << EOF
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
            i += 1
            start += 1
            filepointer += 1
with open(patch, 'w') as f:
    f.writelines(lines)
EOF
    endfunction

    function! EcfgReadCmd(fname)
        let ul_val=&l:ul
        setlocal ul=-1
        silent exe "%!ecfg decrypt ".a:fname
        let b:ecfg_decrypted = 1
        if v:shell_error
            silent exe "%!cat ".a:fname
            let b:ecfg_decrypted = 0
        endif
        setlocal nomodified
        let &l:ul=ul_val
    endfunction

    function! EcfgWriteCmd(type)
        let l:base = expand("<afile>")
        if !b:ecfg_decrypted || !filereadable(l:base)
            call EcfgWriteDirect(a:type)
            return
        endif
        exe "!ecfg decrypt % 1>/dev/null"
        if v:shell_error
            let l:choice = confirm("You appear to be missing the private key to decrypt this file. Write your changes anyway?", "&Yes\n&No")
            if l:choice == 1
                call EcfgWriteDirect(a:type)
            endif
            return
        endif
        let l:tmp = tempname()
        silent exe "w !diff <(ecfg decrypt %) - >".l:tmp
        call PyMerge(l:base, l:tmp)
        silent exe "!patch -s ".l:base." ".l:tmp
        if !v:shell_error
            silent exe "!ecfg encrypt %"
            if !v:shell_error
                setlocal nomodified
            else
                " Undo the patch we just applied
                silent exe "!patch -R -s ".l:base." ".l:tmp
                echohl ErrorMsg
                redraw
                echo "An error occured while trying to encrypt the file."
                echohl NONE
            endif
        else
            echohl ErrorMsg
            redraw
            echo "An error occured while trying to patch the file."
            echohl NONE
        endif
        call delete(l:tmp)
    endfunction

else
    function! EcfgWriteCmd(type)
        call EcfgWriteDirect(a:type)
    endfunction
endif
