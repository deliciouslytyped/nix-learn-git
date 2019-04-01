#TODO consider rewrite with tmuxp
#TODO compare other git repl tools
#some tools
#start tmux setup on shell enter
#ooor..wait for user to init watches
#TODO pinning, maybe try feh from unstable	#TODO id use feh if i could get it to not break
#TODO activation script for tmuxinator because it doesnt support relative paths / try ERB + CLI cwd path?
{stdenv, lib, writeText, writeShellScriptBin,  mkShell, tmuxinator, tmux, okular, feh, graphviz,
python37Packages, fetchFromGitHub, inotify-tools, meld, gitAndTools, bashInteractive, evince}: 
  let
    root = toString ./.;
    workdir = "${root}/workdir";
    repo = "${workdir}/repo";

    git-config = writeText "git-config" ''
      [diff]
        tool = meld
      [difftool]
        prompt = false
      [difftool "meld"]
        cmd = meld "$LOCAL" "$REMOTE"
      [merge]
        tool = meld
      [mergetool "meld"]
        cmd = meld "$LOCAL" "$BASE" "$REMOTE" --output "$MERGED"
      '';

    launch-learn = writeShellScriptBin "launch-learn" ''
      mkdir '${workdir}'
      mkdir '${workdir}'/repo && (pushd '${repo}'; git init; popd;)
      echo NOTE: large and/or dual screens are recommended #TODO not very visible
      cp '${git-config}' '${repo}/.git/config'
      #export PATH=$PATH:${bashInteractive}
      export SHELL="${bashInteractive}"/bin/bash
      tmuxinator start -p ${tmuxinator-config}
      exec attach-learn
      ''; 

    image-watch = writeShellScriptBin "image-watch" ''
      touch "${workdir}"/png.png
      #TODO the -e for this arent quite right? no update on reflog clears or what was it?
      okular "${workdir}"/png.png 2> /dev/null &
      while inotifywait -e create -e delete -e modify -q -r . --exclude '\./\.git/index\.lock'
        do git-draw -i --dot-filename "${workdir}"/dot --image-filename "${workdir}"/png.png
      done
      '';

    git-repl = python37Packages.buildPythonApplication {
      pname = "git-repl";
      version = "placeholder"; #TODO?
      src = fetchFromGitHub {
        owner = "mbr";
        repo = "repl";
        rev = "e3bd9470df36b57a3c7bce0d924154a4de078dc0";
        sha256 = "1z6768hb2m6xjsjpkga9apd8vvb8s7187q7b8ycah0x0bwsgap9n";
        };
      propagatedBuildInputs = with python37Packages; [ click ];
      };

    git-draw = stdenv.mkDerivation {
      name = "git-draw";
      version = "idk"; #TODO
      src = fetchFromGitHub {
        owner = "sensorflo";
        repo = "git-draw";
        rev = "dd1cd6216f48b218d380e7f81e634edde1ce4f0c";
        sha256 = "1zd5k58qj6jz6bfwx66gyppzzhw3vf8rpf951n9zps4g6jkn7bfg";
        };

      installPhase = ''
        mkdir -p "$out/bin"
        cp $src/git-draw "$out/bin"
        '';

      propagatedBuildInputs = [ graphviz ];
      };

    #TODO use ERB var stuff, see readme
    #NOTE layout and minimum size are hardcoded (maybe gets fixed once you actually enter the env)
    #NOTE has hax to pass the size to new-session
    #TODO fix https://github.com/tmuxinator/tmuxinator/issues/686
    tmuxinator-config = writeText "tmuxinator-config" ''
      name: learn-git
      root: '${workdir}'
      socket_path: '${workdir}/socket'

      pre: 'cd "${workdir}" && tmux -S "${workdir}"/socket new-session -d -x 255 -y 75'
      attach: false

      windows: 
        - learngit:
            layout: e892,255x75,0,0[255x37,0,0{127x37,0,0,31,127x37,128,0[127x18,128,0,38,127x7,128,19,39,127x10,128,27,41]},255x37,0,38{127x37,0,38,32,127x37,128,38[127x28,128,38,33,127x8,128,67,34]}]
            panes: 
              - 'cd "${repo}"'
              - 'cd "${repo}" && watch -c -n 0.5 "git status"'
              - 'cd "${repo}" && watch -c -n 0.5 "git log --color=always"'
              - 'cd "${repo}" && watch -c -n 0.5 "ls -Alh --color=always"'
              - 'cd "${repo}"'
              - 'cd "${repo}" && "${git-repl}"/bin/repl git'
              - 'cd "${repo}" && image-watch'
      '';

    kill-learn = writeShellScriptBin "kill-learn" ''
      tmux -S '${workdir}/socket' kill-server 
      '';

    attach-learn = writeShellScriptBin "attach-learn" ''
      tmux -S '${workdir}/socket' attach -t learn-git 
      '';

#    book = fetchUrl {
#      url = "";
#      sha256 = "";
#      };

#    open-book = writeShellScriptBin "open-book" ''
#      evince ${book}
#      '';
  in
    mkShell {
      buildInputs = [ tmux tmuxinator ] ++ #bashInteractive ] ++
                    [ okular feh ] ++
                    [ gitAndTools.gitFull inotify-tools ] ++
                    [ meld ] ++
                    [ launch-learn git-repl git-draw image-watch kill-learn attach-learn ]; 
      }
