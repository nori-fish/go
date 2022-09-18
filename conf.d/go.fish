function _go_install --on-event go_install --on-event go_update
    set --local current_version

    if command --query go
        set current_version (\
            command go version \
            | awk '{print $3}' \
            | string replace --regex '^go' ''\
        )
    end

    set --function page 1
    while test -z "$latest_versions"
        set --function latest_release_json (curl -fs "https://api.github.com/repos/golang/go/tags?per_page=100&page="$page)
        if test (count (echo $latest_release_json | jq -r '.[]')) -eq 0
            echo "Unable to find latest release of Go"
            return 1
        else
            set --function page (math $page + 1)
        end
        set --function latest_versions \
            (echo $latest_release_json \
            | jq -r '.[] | .name | match("^go([0-9]+).([0-9]+)(.([0-9]+))?$") | .captures | [.[0], .[1], .[3]] | map(.string) | map(select(. | length > 0)) | join(".")'\
            )
        set --function latest_version $latest_versions[1]
    end

    if [ "$current_version" != "$latest_version" ]
        if [ "$current_version" ]
            echo "[go] Updating from v$current_version to v$latest_version..."
        else
            echo "[go] Installing v$latest_version"
        end

        set --local name "go"$latest_version".linux-amd64.tar.gz"
        set --local download_url "https://go.dev/dl/"$name
        set --local tmp_dir (mktemp -d /tmp/go.XXXXXXX)
        set --local file_path $tmp_dir/$name

        curl --progress-bar -Lo "$file_path" "$download_url"

        set --query GO_INSTALL
        or set --universal --export GO_INSTALL $HOME/.golang

        rm -rf $GO_INSTALL
        mkdir -p $GO_INSTALL
        tar -C $GO_INSTALL --strip-components=1 -xzf "$file_path"
        rm -rf $tmp_dir

        fish_add_path --prepend $GO_INSTALL/bin
    end
end

function _go_uninstall --on-event go_uninstall
    if set --local index (contains --index $GO_INSTALL/bin $fish_user_paths)
        set --universal --erase fish_user_paths[$index]
    end

    if set --query GO_INSTALL
        rm -rf $GO_INSTALL
        set -Ue GO_INSTALL
    end
end
