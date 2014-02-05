## Scripts

We run them, they do things.

![No Nonsense](http://i.imgur.com/eEuWKmy.gif "No Nonsense")


### Running Bash scripts (log parsing)
Generally, `./script_name.sh` will be enough.

For some scripts you'll need to specify the log file to parse, and the output filename:

```bash
./generate_audio_report.sh logs/media-access.log 2014-01.csv
```


### Running Ruby scripts

Ideally, one could run any of these scripts from the command line, customizing
the output just by modifying the arguments. Run `./script_name.rb -h` to see
what the options are. Not all scripts have been converted to this format yet.

When running a script, you should be running it in the same environment
as the target application. So if you want to run a script for SCPRv4, you should
first run `rvm use 1.9.3@scprv4` or `chruby 1.9.3` or whatever you need to do.
Also recommended is simply placing a `.ruby-version` file in the SCPRv4
directory in this repository (please don't commit it).

You'll need to define `PROJECT_HOME` in your bash/zsh/whatever environment.
This is so the scripts know where to find your projects. It assumes they're all
in the same directory:

```
echo "export PROJECT_HOME=/path/to/your/projects" >> ~/.bash_profile
```


### New scripts

* Specify the shebang at the top of the file. See other scripts for an example.
* Use `OptionsParser` to accept some arguments, unless the script is *really*
specialized. Either way, save the script here.
* Set `APP` to the name of the directory where the target application lives.
* Set `SCRIPT` to the name of the script.
* Require the `util/setup.rb` file - this will load the rails environment.
* Gist Upload can be added to the bottom of any file to add optional gisting of
the generated file.


### TODO
Eventually it would be nice to clean up and organize the scripts a little bit.
If we moved some common code into reusable modules, it would make these scripts
more useful all-around.
