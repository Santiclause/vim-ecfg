au BufNewFile *.ecfg.yaml call EcfgCreate("yaml")
au BufNewFile *.ecfg.json call EcfgCreate("json")
au BufWriteCmd,FileWriteCmd *.ecfg.yaml call EcfgWriteCmd("yaml")
au BufWriteCmd,FileWriteCmd *.ecfg.toml call EcfgWriteCmd("toml")
au BufWriteCmd,FileWriteCmd *.ecfg.json call EcfgWriteCmd("json")

let s:path = fnamemodify(resolve(expand('<sfile>:p')), ':h')

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


if has("python") || has("python3")
    au BufReadPost,FileReadPost *.ecfg.yaml,*.ecfg.toml,*.ecfg.json call EcfgReadCmd(expand("<afile>"))

    function! PyMerge(base, patch)
        let merge_script = join(readfile(s:path . '/merge_script.py'), "\n")

        if has('python')
            execute 'py ' . merge_script
        else
            execute 'py3 ' . merge_script
        endif
    endfunction

    function! EcfgReadCmd(fname)
        let ul_val=&l:ul
        setlocal ul=-1
        silent exe "%!ecfg decrypt ".a:fname
        if v:shell_error
            silent exe "%!cat ".a:fname
            let b:ecfg_not_decrypted = 1
        endif
        setlocal nomodified
        let &l:ul=ul_val
    endfunction

    function! EcfgWriteCmd(type)
        let l:base = expand("<afile>")
        if exists("b:ecfg_not_decrypted") || !filereadable(l:base)
            call EcfgWriteDirect(a:type)
            return
        endif
        silent exe "!ecfg decrypt % 1>/dev/null"
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
            silent exe "!ecfg encrypt % >/dev/null"
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
