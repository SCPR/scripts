## Scripts

We run them, they do things. Mostly used for generating custom CSV reports.

![No Nonsense](http://i.imgur.com/eEuWKmy.gif "No Nonsense")


### Running scripts

Ideally, one could run any of these scripts from the command line, customizing
the output just by modifying the arguments. Run `./script_name.rb -h` to see
what the options are. Not all scripts have been converted to this format yet.

When running a script, you should be running it in the same RVM environment
as the target application. So if you want to run a script for SCPRv4, you should
first run `rvm use 1.9.3@scprv4`. Also recommended is simply placing an `.rvmrc`
file in the SCPRv4 directory in this repository (please don't commit it).


### New scripts

* Specify the shebang at the top of the file. See other scripts for an example.
* Use `OptionsParser` to accept some arguments, unless the script is *really*
specialized. Either way, save the script here.
* Make sure you have `PROJECT_HOME` defined in your bash environment.
* Set `APP` to the name of the directory where the target application lives.
* Set `SCRIPT` to the name of the script.
* Require the `util/setup.rb` file - this will load the rails environment.
* Gist Upload can be added to the bottom of any file to add optional gisting of
the generated file.


### TODO
Eventually it would be nice to clean up and organize the scripts a little bit.
If we moved some common code into reusable modules, it would make these scripts
more useful all-around.
