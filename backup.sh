#!/usr/bin/env python3

import subprocess
import os
import shutil # For checking if 'filen' command exists
import json   # To parse JSON output from filen
import sys    # For flushing, stderr, exit, version, executable
import traceback # For detailed error reporting
import re     # For stripping Rich markup in fallback console

RICH_AVAILABLE = False
console = None # Initialize console to None
# Declare Rich components at a scope accessible by FallbackConsole if needed,
# but primarily for global use when RICH_AVAILABLE is True.
Console, Panel, Text, Padding, Align, Live, Spinner, Rule, Syntax = (None,) * 9

try:
    import rich
    # Import specific components
    from rich.console import Console
    from rich.panel import Panel
    from rich.text import Text
    from rich.padding import Padding
    from rich.align import Align
    from rich.live import Live
    from rich.spinner import Spinner
    from rich.rule import Rule
    from rich.syntax import Syntax
    
    rich_version_str = "unknown"
    if hasattr(rich, '__version__'):
        rich_version_str = rich.__version__
    
    rich_file_str = "unknown"
    if hasattr(rich, '__file__'):
        rich_file_str = rich.__file__
        script_dir = os.path.dirname(os.path.abspath(__file__))
        if rich_file_str and rich_file_str.startswith(script_dir) and \
           (rich_file_str.endswith('.py') or os.path.isdir(rich_file_str)):
             print(f"WARNING: Imported 'rich' module ({rich_file_str}) might be a local file/directory shadowing the installed library.", file=sys.stderr)

    RICH_AVAILABLE = True
except ImportError as e:
    print(f"ERROR: Failed to import Rich or one of its components: {e}", file=sys.stderr)
    RICH_AVAILABLE = False
except AttributeError as e: 
    print(f"ERROR: AttributeError during Rich import (e.g., missing __version__ or component): {e}", file=sys.stderr)
    print("This might indicate a broken Rich installation or a local 'rich.py' file shadowing the library.", file=sys.stderr)
    traceback.print_exc(file=sys.stderr)
    RICH_AVAILABLE = False
except Exception as e:
    print(f"ERROR: An unexpected error occurred during Rich import: {e}", file=sys.stderr)
    traceback.print_exc(file=sys.stderr)
    RICH_AVAILABLE = False

# --- Configuration ---
SYNC_TASKS = [
    {
        "local_path": "/home/florian/Obsidian",
        "remote_folder_name": "Obsidian",
        "sync_mode": "localToCloud",
        "description": "Obsidian Vault",
    },
    {
        "local_path": "/home/florian/Benchmark",
        "remote_folder_name": "Benchmark",
        "sync_mode": "localToCloud",
        "description": "Benchmark Data",
    },
    {
        "local_path": "/home/florian/Fedora_Setup",
        "remote_folder_name": "Fedora_Setup",
        "sync_mode": "localToCloud",
        "description": "Fedora Setup Scripts",
    },
    {
        "local_path": "/home/florian/Finanzen",
        "remote_folder_name": "Finanzen",
        "sync_mode": "localToCloud",
        "description": "Finanzen Documents",
    },
]
EXTERNAL_SSD_MOUNT_POINT = "/run/media/florian/FloriansSSD"
FILEN_BACKUP_TARGET_DIR_ON_SSD = "Filen-Backup"
FULL_BACKUP_SYNC_MODE = "cloudToLocal"
DISABLE_SSD_BACKUP_LOCAL_TRASH = True
# --- End Configuration ---


# --- Initialize Console (Rich or Fallback) ---
if RICH_AVAILABLE:
    try:
        try:
            terminal_width = os.get_terminal_size().columns
        except OSError: 
            terminal_width = 120 
            print("Could not get terminal_size, using default width 120 for Rich Console.")

        # Use the globally imported Console
        console = Console(
            force_terminal=True,
            color_system="auto",
            width=terminal_width,
            log_time=False,
            log_path=False
        )
        # console.print("[green]Rich Console Test: This is a test print from Rich Console.[/green]") # Optional test
    except Exception as e:
        print(f"ERROR: Failed to initialize Rich Console: {e}", file=sys.stderr)
        traceback.print_exc(file=sys.stderr)
        RICH_AVAILABLE = False 
        print("Falling back to basic console due to Rich Console initialization error.", file=sys.stderr)

if not RICH_AVAILABLE or console is None:
    if console is None and RICH_AVAILABLE: # Should not happen if init logic is correct, but safety
        print("Warning: RICH_AVAILABLE is True, but console is None. Forcing Fallback.", file=sys.stderr)

    class FallbackConsole:
        def _strip_markup(self, text_string):
            if not isinstance(text_string, str):
                text_string = str(text_string)
            # More comprehensive Rich tag stripping
            text_string = re.sub(r'\[(/?)(b|i|u|s|blink|strike|reverse|dim|italic|bold|underline|style|on\s\w+|link(?:=[^\]]+)?)\]', '', text_string)
            # Color tags
            text_string = re.sub(r'\[(bright_black|bright_red|bright_green|bright_yellow|bright_blue|bright_magenta|bright_cyan|bright_white|black|red|green|yellow|blue|magenta|cyan|white|grey\d*|rgb\([\d,]+\)|#[0-9a-fA-F]{3,6})\]', '', text_string)
            text_string = re.sub(r'\[/\]', '', text_string) # Closing tag for colors/styles
            return text_string

        def _render_rich_object_to_plain_text(self, obj):
            if isinstance(obj, str):
                return self._strip_markup(obj)
            
            _LocalText = Text
            _LocalRule = Rule
            _LocalPanel = Panel
            _LocalPadding = Padding
            _LocalAlign = Align
            _LocalSpinner = Spinner
            _LocalSyntax = Syntax

            if _LocalText and isinstance(obj, _LocalText):
                return obj.plain
            if _LocalRule and isinstance(obj, _LocalRule):
                title = obj.title if hasattr(obj,'title') else ""
                if _LocalText and isinstance(title, _LocalText): title = title.plain
                elif not isinstance(title, str): title = str(title)
                title = self._strip_markup(title)
                
                char = obj.characters if hasattr(obj,'characters') else "-"
                try: width = os.get_terminal_size().columns
                except OSError: width = 80

                if not title or title.isspace(): return char * width
                
                title_len = len(title)
                if title_len == 0: return char * width
                if title_len + 4 > width : return f"{char*2} {title} {char*2}" # Handle too long titles gracefully

                line_len = max(0, (width - title_len - 2) // 2)
                left_line = char * line_len
                right_line = char * max(0, (width - title_len - 2 - line_len)) # Ensure right_line is not negative
                return f"{left_line} {title} {right_line}"

            if _LocalPanel and isinstance(obj, _LocalPanel):
                content_text = self._render_rich_object_to_plain_text(obj.renderable if hasattr(obj,'renderable') else "")
                output = ""
                if hasattr(obj,'title') and obj.title:
                    title_str = self._render_rich_object_to_plain_text(obj.title)
                    output += f"--- {title_str} ---\n"
                output += content_text
                # Could add borders here if desired, e.g. output += "\n--------------"
                return output

            if _LocalPadding and isinstance(obj, _LocalPadding):
                # For simplicity, fallback padding doesn't add actual spaces unless implemented
                return self._render_rich_object_to_plain_text(obj.renderable if hasattr(obj, 'renderable') else "")
            
            if _LocalAlign and isinstance(obj, _LocalAlign):
                # Fallback align just prints the content
                renderable_to_align = obj.renderable if hasattr(obj, 'renderable') else ""
                if isinstance(renderable_to_align, tuple) and len(renderable_to_align) > 0: # rich.align.Align takes renderable or (renderable, vertical_alignment)
                     actual_renderable = renderable_to_align[0]
                else:
                     actual_renderable = renderable_to_align
                return self._render_rich_object_to_plain_text(actual_renderable)

            if _LocalSpinner and isinstance(obj, _LocalSpinner):
                if hasattr(obj, 'text') and obj.text:
                    return self._render_rich_object_to_plain_text(obj.text)
                return "[Spinner]" # Simple placeholder
            
            if _LocalSyntax and isinstance(obj, _LocalSyntax):
                return obj.code if hasattr(obj, 'code') else "[Syntax Content]"


            # Fallback for other Rich objects or unknown types
            return self._strip_markup(str(obj))

        def print(self, message="", *args, **kwargs_inner):
            plain_text_message = self._render_rich_object_to_plain_text(message)
            print(plain_text_message, *args, **kwargs_inner) # Use standard print

        def status(self, status_text_obj="Processing...", *args_status, **kwargs_status):
            fallback_console_instance = self # For clarity within DummyStatus
            class DummyStatus:
                def __init__(self, initial_status_text_obj, console_instance):
                    self.console_instance = console_instance
                    self.status_text = self.console_instance._render_rich_object_to_plain_text(initial_status_text_obj)
                    # Ensure it ends with "..."
                    self.status_text = self.status_text.split("...", 1)[0] + "..."
                    self.console_instance.print(self.status_text) # Print initial status

                def __enter__(self): return self
                def __exit__(self, exc_type, exc_val, exc_tb): pass # No cleanup needed for basic print
                def update(self, new_status_text_obj):
                    new_text = self.console_instance._render_rich_object_to_plain_text(new_status_text_obj)
                    self.status_text = new_text.split("...", 1)[0] + "..."
                    self.console_instance.print(f"Status update: {self.status_text}") # Print updates
            
            return DummyStatus(status_text_obj, fallback_console_instance)

        def live(self, renderable_or_text, *args_live, **kwargs_live):
            fallback_console_instance = self # For clarity
            class DummyLive:
                def __init__(self, initial_renderable, console_instance):
                    self.console_instance = console_instance
                    initial_text = self.console_instance._render_rich_object_to_plain_text(initial_renderable)
                    self.console_instance.print(initial_text + " (live display simulation)...")

                def __enter__(self): return self
                def __exit__(self,t,v,tb): pass # No cleanup
                def update(self, new_renderable_or_text):
                    update_text = self.console_instance._render_rich_object_to_plain_text(new_renderable_or_text)
                    self.console_instance.print(f"Live Update: {update_text}")
            
            return DummyLive(renderable_or_text, fallback_console_instance)

    console = FallbackConsole()
    if RICH_AVAILABLE: # This means Rich was imported but Console init failed
        console.print("Fallback Console initialized because Rich Console failed during/after import.")
    else: # Rich was not imported at all
        console.print("Rich library not found or import failed. Output will be basic.")
        if 'rich' not in sys.modules: # Check if 'rich' module itself is not in sys.modules
             console.print("Consider installing it with: pip install rich")


# --- Helper Functions (reusable) ---
def _run_filen_command(command_args, operation_description, live_spinner_text, disable_local_trash_for_this_op=False):
    if disable_local_trash_for_this_op:
        command_args.append("--disable-local-trash")

    live_display_context = None
    if RICH_AVAILABLE and console and hasattr(console, 'status') and callable(console.status) and Live and Text and Spinner:
        spinner_graphic = Spinner("dots", text=Text(live_spinner_text, style="cyan"))
        live_display_context = Live(spinner_graphic, console=console, refresh_per_second=10, vertical_overflow="visible", transient=True)
    else:
        live_display_context = console.live(live_spinner_text) 

    process_successful = False
    filen_json_errors = None
    filen_raw_stdout = ""
    filen_raw_stderr = ""

    with live_display_context as live_display: 
        try:
            process = subprocess.run(command_args, capture_output=True, text=True, check=False, encoding='utf-8', errors='replace')
            filen_raw_stdout = process.stdout.strip() if process.stdout else ""
            filen_raw_stderr = process.stderr.strip() if process.stderr else ""
            process_successful = process.returncode == 0
            
            # Attempt to parse JSON errors from stdout
            if filen_raw_stdout.startswith("{") or filen_raw_stdout.startswith("["):
                # Filen CLI sometimes appends "Done." after JSON output.
                json_part = filen_raw_stdout.split("Done.", 1)[0].strip()
                if json_part: # Ensure json_part is not empty before trying to load
                   try:
                       parsed_output = json.loads(json_part)
                       # Check if it's the specific error structure Filen CLI uses
                       if isinstance(parsed_output, dict) and parsed_output.get("type") == "taskErrors" and \
                          "data" in parsed_output and isinstance(parsed_output["data"].get("errors"), list):
                            filen_json_errors = parsed_output["data"]["errors"]
                   except json.JSONDecodeError:
                       # Not fatal, just means stdout wasn't the error JSON we expected.
                       # Could log this to a debug file if necessary in the future.
                       pass # Silently ignore if JSON parsing fails, rely on return code
                   except Exception as e: # Catch other potential errors during parsing
                       # Update spinner/live display with a warning about parsing
                       update_msg_content = f"Warning: Error parsing Filen JSON: {e}"
                       update_text_obj = Text(update_msg_content, style="yellow") if RICH_AVAILABLE and Text else update_msg_content
                       if hasattr(live_display, 'update'): live_display.update(update_text_obj)
                       else: console.print(str(update_text_obj))


            # Update spinner/live with final status
            update_msg_success = f"✓ {operation_description} complete."
            update_msg_fail = f"✗ {operation_description} failed."
            
            if process_successful:
                update_text_obj = Text(update_msg_success, style="green") if RICH_AVAILABLE and Text else update_msg_success
            else:
                update_text_obj = Text(update_msg_fail, style="red") if RICH_AVAILABLE and Text else update_msg_fail
            
            if hasattr(live_display, 'update'): live_display.update(update_text_obj)
            else: console.print(str(update_text_obj)) # For FallbackLive which doesn't have .update


        except FileNotFoundError:
            err_msg_fnf = "✗ 'filen' command not found."
            update_text_obj = Text(err_msg_fnf, style="red") if RICH_AVAILABLE and Text else err_msg_fnf
            if hasattr(live_display, 'update') : live_display.update(update_text_obj)
            else: console.print(str(update_text_obj))

            panel_content = "[bold red]ERROR:[/] 'filen' command not found. Is it installed and in your PATH?"
            panel_title = "[red]Execution Error[/red]"
            if RICH_AVAILABLE and Panel and Text:
                 console.print(Panel(Text.from_markup(panel_content), title=panel_title, border_style="red"))
            else:
                 console.print(f"--- {console._render_rich_object_to_plain_text(panel_title)} ---")
                 console.print(console._render_rich_object_to_plain_text(panel_content))
            return False # Explicitly return False for FileNotFoundError
        except Exception as e:
            # This catches other Python exceptions during subprocess.run or live display logic
            print(f"ERROR: Python Exception in _run_filen_command: {e}", file=sys.stderr)
            traceback.print_exc(file=sys.stderr)
            err_msg_py_ex = f"✗ Python Exception: {e}"
            update_text_obj = Text(err_msg_py_ex, style="red") if RICH_AVAILABLE and Text else err_msg_py_ex
            if hasattr(live_display, 'update'): live_display.update(update_text_obj)
            else: console.print(str(update_text_obj))

            panel_content_ex = str(e)
            panel_title_ex = "[red]Unexpected Python Exception[/red]"
            if RICH_AVAILABLE and Panel and Text:
                console.print(Panel(Text(panel_content_ex), title=panel_title_ex, border_style="red"))
            else:
                console.print(f"--- {console._render_rich_object_to_plain_text(panel_title_ex)} ---")
                console.print(panel_content_ex)
            return False

    # Post-live display processing and final status reporting
    if process_successful and not filen_json_errors:
        msg_text = f"✅ {operation_description} Successful!"
        title_text = "[green]Status[/green]"
        if RICH_AVAILABLE and Panel and Text:
            console.print(Panel(Text.from_markup(msg_text), title=title_text, border_style="green", expand=False))
        else:
            console.print(f"--- {console._render_rich_object_to_plain_text(title_text)} ---")
            console.print(console._render_rich_object_to_plain_text(msg_text))
        return True
    elif filen_json_errors: # Process was successful (RC=0) but Filen reported specific errors in its JSON
        msg_text = f"⚠️ Warning: {operation_description} Completed with Errors!"
        title_text = "[yellow]Status[/yellow]"
        if RICH_AVAILABLE and Panel and Text:
            console.print(Panel(Text.from_markup(msg_text), title=title_text, border_style="yellow", expand=False))
        else:
            console.print(f"--- {console._render_rich_object_to_plain_text(title_text)} ---")
            console.print(console._render_rich_object_to_plain_text(msg_text))

        console.print(f"[yellow]Filen reported {len(filen_json_errors)} specific issues:[/yellow]")
        for i, error in enumerate(filen_json_errors[:10]): # Show first 10 errors
            path = error.get('path', 'N/A')
            error_type = error.get('type', 'N/A')
            message = error.get('error', {}).get('message', 'Unknown error')
            console.print(f"  ({i+1}) {error_type}: On path '{path}' - {message}")
        if len(filen_json_errors) > 10:
            console.print(f"  ... {len(filen_json_errors) - 10} more errors not shown.")
        return False # Treat as failure if Filen reports errors, even with RC 0
    else: # process_successful is False (non-zero return code)
        msg_text = f"❌ ERROR: {operation_description} Failed!\nReturn Code: {process.returncode if 'process' in locals() else 'N/A'}"
        title_text = "[red]Operation Error[/red]"
        if RICH_AVAILABLE and Panel and Text:
            console.print(Panel(Text.from_markup(msg_text), title=title_text, border_style="red", expand=False))
        else:
            console.print(f"--- {console._render_rich_object_to_plain_text(title_text)} ---")
            console.print(console._render_rich_object_to_plain_text(msg_text))
        
        # Display Filen CLI's stdout/stderr if available and an error occurred
        error_content_str = ""
        if filen_raw_stdout: error_content_str += f"Filen STDOUT:\n{filen_raw_stdout}\n\n"
        if filen_raw_stderr: error_content_str += f"Filen STDERR:\n{filen_raw_stderr}"

        if error_content_str:
            panel_title_details = "[yellow]Filen CLI Details[/yellow]"
            if RICH_AVAILABLE and Panel and Text:
                 console.print(Panel(Text(error_content_str.strip()), title=panel_title_details, border_style="yellow", expand=False))
            else:
                 console.print(f"--- {console._render_rich_object_to_plain_text(panel_title_details)} ---")
                 console.print(error_content_str.strip())
        else: console.print("[yellow]No specific STDOUT/STDERR from Filen CLI to display.[/yellow]")
        return False

def check_filen_cli_installed():
    if not shutil.which("filen"):
        error_message_content = "ERROR: 'filen' CLI tool not found in your PATH.\n\nPlease install it first: curl -sL https://filen.io/cli.sh | bash"
        panel_title = "[red]Prerequisite Missing[/red]"
        if RICH_AVAILABLE and Panel and Text:
            console.print(Panel(Text.from_markup(error_message_content), title=panel_title, border_style="red", expand=False))
        else:
            console.print(f"--- {console._render_rich_object_to_plain_text(panel_title)} ---")
            console.print(console._render_rich_object_to_plain_text(error_message_content))
        return False
    return True

def create_remote_dir_if_not_exists(remote_folder_name, item_description="directory"):
    remote_path = f"/{remote_folder_name}" # Filen paths usually start with / for root
    
    spinner_message_checking_str = f"[cyan]Checking Filen for {item_description} [bold white]'{remote_path}'[/bold white]..."
    spinner_message_creating_str = f"[yellow]Filen {item_description} [bold white]'{remote_path}'[/bold white] not found. Creating..."

    status_context = console.status(spinner_message_checking_str) 

    with status_context as status_spinner: 
        stat_command = ["filen", "--skip-update", "stat", remote_path]
        try:
            process = subprocess.run(stat_command, capture_output=True, text=True, check=False, encoding='utf-8', errors='replace')

            if process.returncode == 0:
                update_msg_str = f"[green]✓ Filen {item_description} [bold white]'{remote_path}'[/bold white] found."
                if hasattr(status_spinner, 'update'): status_spinner.update(update_msg_str)
                else: console.print(update_msg_str)
                return True

            # Check common "not found" messages in stderr or stdout (Filen CLI behavior can vary)
            stderr_lower = process.stderr.lower() if process.stderr else ""
            stdout_lower = process.stdout.lower() if process.stdout else "" # some errors appear on stdout
            if "no such file or directory" in stderr_lower or \
               "no such cloud file or directory" in stderr_lower or \
               "404" in stderr_lower or "404" in stdout_lower: # HTTP 404 might also indicate not found

                if hasattr(status_spinner, 'update'): status_spinner.update(spinner_message_creating_str)
                else: console.print(spinner_message_creating_str)

                mkdir_command = ["filen", "--skip-update", "mkdir", remote_path]
                mkdir_process = subprocess.run(mkdir_command, capture_output=True, text=True, check=False, encoding='utf-8', errors='replace')

                if mkdir_process.returncode == 0:
                    console.print(f"[green]✓ Created Filen {item_description} [bold green]'{remote_path}'[/bold green].")
                    return True
                else:
                    update_msg_fail_str = f"[red]✗ Failed to create Filen {item_description} [bold white]'{remote_path}'[/bold white]."
                    if hasattr(status_spinner, 'update'): status_spinner.update(update_msg_fail_str)
                    else: console.print(update_msg_fail_str)

                    error_details_content = ""
                    if mkdir_process.stdout and mkdir_process.stdout.strip(): error_details_content += f"STDOUT:\n{mkdir_process.stdout.strip()}\n"
                    if mkdir_process.stderr and mkdir_process.stderr.strip(): error_details_content += f"STDERR:\n{mkdir_process.stderr.strip()}"
                    
                    panel_title = f"[red]mkdir Error for {remote_path}[/red]"
                    if error_details_content:
                        if RICH_AVAILABLE and Panel and Text:
                             console.print(Panel(Text(error_details_content), title=panel_title, border_style="red", expand=False))
                        else:
                             console.print(f"--- {console._render_rich_object_to_plain_text(panel_title)} ---")
                             console.print(error_details_content)
                    return False
            else: # 'filen stat' failed for a reason other than "not found"
                update_msg_other_err_str = f"[red]✗ Error checking Filen {item_description} [bold white]'{remote_path}'[/bold white]."
                if hasattr(status_spinner, 'update'): status_spinner.update(update_msg_other_err_str)
                else: console.print(update_msg_other_err_str)

                error_details_stat_content = f"filen stat command failed for {remote_path}.\n"
                if process.stdout and process.stdout.strip(): error_details_stat_content += f"STDOUT:\n{process.stdout.strip()}\n"
                if process.stderr and process.stderr.strip(): error_details_stat_content += f"STDERR:\n{process.stderr.strip()}"
                
                panel_title_stat = f"[red]stat Error for {remote_path}[/red]"
                if RICH_AVAILABLE and Panel and Text:
                    console.print(Panel(Text(error_details_stat_content), title=panel_title_stat, border_style="red", expand=False))
                else:
                    console.print(f"--- {console._render_rich_object_to_plain_text(panel_title_stat)} ---")
                    console.print(error_details_stat_content)
                return False
        except Exception as e:
            # Python-level exception during the process
            print(f"ERROR: Python Exception in create_remote_dir: {e}", file=sys.stderr)
            traceback.print_exc(file=sys.stderr)
            update_msg_py_ex_str = f"[red]✗ Exception while checking/creating Filen {item_description}."
            if hasattr(status_spinner, 'update'): status_spinner.update(update_msg_py_ex_str)
            else: console.print(update_msg_py_ex_str)
            
            panel_title_py_ex = "[red]Python Exception[/red]"
            if RICH_AVAILABLE and Panel:
                console.print(Panel(str(e), title=panel_title_py_ex, border_style="red"))
            else:
                console.print(f"--- {console._render_rich_object_to_plain_text(panel_title_py_ex)} ---")
                console.print(str(e))
            return False

# --- Sync Task Processing Logic ---
def perform_sync_task(task_config):
    local_path = task_config["local_path"]
    remote_folder_name = task_config["remote_folder_name"]
    sync_mode = task_config["sync_mode"]
    description = task_config["description"]
    disable_trash = task_config.get("disable_local_trash", False) # Get optional setting

    if not os.path.isdir(local_path):
        panel_content = f"[bold red]ERROR:[/] Local path '{local_path}' for '{description}' not found or not a directory."
        panel_title = f"[red]{description} - Path Error[/red]"
        if RICH_AVAILABLE and Panel and Text:
             console.print(Panel(Text.from_markup(panel_content), title=panel_title, border_style="red"))
        else:
             console.print(f"--- {console._render_rich_object_to_plain_text(panel_title)} ---")
             console.print(console._render_rich_object_to_plain_text(panel_content))
        return False

    if not create_remote_dir_if_not_exists(remote_folder_name, item_description=f"'{description}' target directory"):
        console.print(f"[red]Halting sync for '{description}' due to issues with remote directory.[/red]")
        return False

    remote_filen_path = f"/{remote_folder_name}"
    sync_pair = f"{local_path}:{sync_mode}:{remote_filen_path}"
    command_args = ["filen", "--skip-update", "sync", sync_pair]

    # Build informative string for printing
    sync_info_str_parts = [
        f"Syncing: {local_path}",
        f" → Filen:{remote_filen_path}",
        f" (Mode: {sync_mode})"
    ]
    if disable_trash:
        sync_info_str_parts.append(f" (Local Trash Disabled)")
    
    full_sync_info_str = "".join(sync_info_str_parts)

    if RICH_AVAILABLE and Text and Padding:
        rich_sync_info_str = f"[dim]Syncing: [/dim][white]{local_path}[/white]" + \
                             f"[dim blue] → [/dim blue][white]Filen:{remote_filen_path}[/white]" + \
                             f"[dim] (Mode: {sync_mode})[/dim]"
        if disable_trash:
            rich_sync_info_str += f"[dim yellow] (Local Trash Disabled)[/dim yellow]"
        console.print(Padding(Text.from_markup(rich_sync_info_str), (0,0,1,0))) # Padding bottom
    else:
        console.print(Padding(full_sync_info_str, (0,0,1,0)))


    operation_desc_for_helper = f"{description} sync"
    spinner_text_for_helper = f" Syncing {description} to Filen..."

    return _run_filen_command(command_args, operation_desc_for_helper, spinner_text_for_helper, disable_local_trash_for_this_op=disable_trash)


# --- Full Filen Drive Backup to SSD Logic ---
def check_ssd_and_backup_filen_drive():
    rule_title = "[bold green]Full Filen Drive Backup to External SSD[/bold green]"
    if RICH_AVAILABLE and Rule: console.print(Rule(title=rule_title, style="green"))
    else: console.print(console._render_rich_object_to_plain_text(rule_title))

    target_backup_full_path = os.path.join(EXTERNAL_SSD_MOUNT_POINT, FILEN_BACKUP_TARGET_DIR_ON_SSD)

    console.print(f"Checking for external SSD at: [yellow]{EXTERNAL_SSD_MOUNT_POINT}[/yellow]")
    if not os.path.ismount(EXTERNAL_SSD_MOUNT_POINT):
        console.print(f"[cyan]Info:[/cyan] External SSD mount point [yellow]'{EXTERNAL_SSD_MOUNT_POINT}'[/yellow] is not mounted or not found.")
        console.print("[cyan]Info:[/cyan] Skipping full Filen Drive backup to SSD.")
        return None # Indicates skipped, not failure

    console.print(f"[green]✓ External SSD detected at [yellow]'{EXTERNAL_SSD_MOUNT_POINT}'[/yellow].")
    console.print(f"Target backup directory on SSD: [yellow]{target_backup_full_path}[/yellow]")

    if not os.path.exists(target_backup_full_path):
        console.print(f"[yellow]Target directory '{target_backup_full_path}' does not exist. Attempting to create...[/yellow]")
        try:
            os.makedirs(target_backup_full_path, exist_ok=True)
            console.print(f"[green]✓ Created target directory on SSD: '{target_backup_full_path}'[/green]")
        except OSError as e:
            panel_content = f"❌ ERROR: Could not create target directory on SSD.\nPath: {target_backup_full_path}\nError: {e}"
            panel_title="[red]SSD Directory Error[/red]"
            if RICH_AVAILABLE and Panel and Text:
                console.print(Panel(Text.from_markup(panel_content), title=panel_title, border_style="red"))
            else:
                console.print(f"--- {console._render_rich_object_to_plain_text(panel_title)} ---")
                console.print(console._render_rich_object_to_plain_text(panel_content))
            return False # Indicates failure

    # Sync entire Filen drive (cloud root "/") to the target path on SSD
    # Format: local_path:sync_mode:remote_path
    # Here, "local" is the SSD path, "remote" is Filen cloud root "/"
    sync_pair = f"{target_backup_full_path}:{FULL_BACKUP_SYNC_MODE}:/"
    command_args = ["filen", "--skip-update", "sync", sync_pair]

    sync_info_str_plain = f"Syncing: Filen Cloud (Root) → {target_backup_full_path} (Mode: {FULL_BACKUP_SYNC_MODE})"
    if DISABLE_SSD_BACKUP_LOCAL_TRASH:
        sync_info_str_plain += " (Local Trash Disabled: True)"

    if RICH_AVAILABLE and Text and Padding:
        rich_sync_info_str = f"[dim]Syncing: [/dim][white]Filen Cloud (Root)[/white]" + \
                             f"[dim green] → [/dim green][white]{target_backup_full_path}[/white]" + \
                             f"[dim] (Mode: {FULL_BACKUP_SYNC_MODE})[/dim]"
        if DISABLE_SSD_BACKUP_LOCAL_TRASH:
            rich_sync_info_str += f"[dim yellow] (Local Trash Disabled: True)[/dim yellow]"
        console.print(Padding(Text.from_markup(rich_sync_info_str), (0,0,1,0))) # Padding bottom
    else:
        console.print(Padding(sync_info_str_plain, (0,0,1,0)))


    return _run_filen_command(command_args, "Full Filen Drive backup", " Syncing entire Filen Drive to external SSD...", disable_local_trash_for_this_op=DISABLE_SSD_BACKUP_LOCAL_TRASH)


# --- Main Execution ---
if __name__ == "__main__":
    overall_success_flag = True # Assume success until a failure occurs
    try:
        # Display script title panel
        panel_title_main = "[magenta]Backup Script[/magenta]"
        panel_content_main = f"[bold bright_magenta]Filen Cloud Backup Utility[/]\nMulti-Routine Script"
        panel_subtitle_main = f"[dim cyan]v1.3[/dim cyan]" # Removed .debug

        if RICH_AVAILABLE and Panel and Align and Text:
            console.print(Panel(
                Align.center(Text.from_markup(panel_content_main)),
                title=panel_title_main,
                subtitle=Text.from_markup(panel_subtitle_main),
                border_style="magenta"
            ))
        else:
            console.print(f"--- {console._render_rich_object_to_plain_text(panel_title_main)} ---")
            console.print(console._render_rich_object_to_plain_text(panel_content_main))
            console.print(f"Subtitle: {console._render_rich_object_to_plain_text(panel_subtitle_main)}")


        if not check_filen_cli_installed():
            # Error message already printed by check_filen_cli_installed
            sys.exit(1)

        general_sync_results = []
        all_general_syncs_succeeded = True

        if SYNC_TASKS:
            rule_title_cloud_sync = "[bold blue]Cloud Sync Tasks[/bold blue]"
            if RICH_AVAILABLE and Rule: console.print(Rule(title=rule_title_cloud_sync, style="blue"))
            else: console.print(console._render_rich_object_to_plain_text(rule_title_cloud_sync))
            
            for i, task in enumerate(SYNC_TASKS):
                # Task-specific rule/header
                rule_title_task = f"[bold cyan]Task: {task['description']}[/bold cyan]"
                # Create a Rule object if Rich is available, otherwise get plain text
                padding_content_task_rule_obj = Rule(title=rule_title_task, style="cyan", characters="·") if RICH_AVAILABLE and Rule else console._render_rich_object_to_plain_text(rule_title_task)
                
                if RICH_AVAILABLE and Padding:
                    console.print(Padding(padding_content_task_rule_obj, (1,0,0,0))) # Padding top
                else:
                    # Fallback console will handle the Rule object or plain text
                    console.print(padding_content_task_rule_obj) # FallbackConsole's print will render Rule or use plain text

                success = perform_sync_task(task)
                general_sync_results.append({"description": task['description'], "success": success})
                if not success:
                    all_general_syncs_succeeded = False
                console.print("") # Add a blank line for spacing after each task's output
        else:
            console.print("[yellow]No general cloud sync tasks configured.[/yellow]\n")


        # Perform SSD backup check and operation
        ssd_backup_status = check_ssd_and_backup_filen_drive()
        # ssd_backup_status can be True (success), False (failure), or None (skipped)

        # Overall Summary Section
        # Use terminal width for a full-width separator if possible
        separator_char = "="
        try: term_width = os.get_terminal_size().columns if console is None or RICH_AVAILABLE else 80
        except OSError: term_width = 80
        console.print("\n" + separator_char * term_width + "\n")
        
        rule_title_summary = "[bold]Overall Summary[/bold]"
        if RICH_AVAILABLE and Rule: console.print(Rule(title=rule_title_summary, style="dim"))
        else: console.print(console._render_rich_object_to_plain_text(rule_title_summary))


        if not SYNC_TASKS:
            console.print("[cyan]ℹ No general cloud sync tasks were configured to run.[/cyan]")
        else:
            for result in general_sync_results:
                if result['success']:
                    console.print(f"[green]✓ {result['description']} cloud sync: Successful[/green]")
                else:
                    console.print(f"[red]✗ {result['description']} cloud sync: Failed or Encountered Errors[/red]")

        # Report SSD backup status
        if ssd_backup_status is None:
            console.print("[cyan]ℹ Full Filen Drive backup to SSD: Skipped (SSD not detected)[/cyan]")
        elif ssd_backup_status is True:
            console.print("[green]✓ Full Filen Drive backup to SSD: Successful[/green]")
        else: # ssd_backup_status is False
            console.print("[red]✗ Full Filen Drive backup to SSD: Failed or Encountered Errors[/red]")

        # Determine overall script success for exit code
        # It's an overall failure if any general sync failed OR if SSD backup explicitly failed (not skipped)
        overall_success_flag = all_general_syncs_succeeded and (ssd_backup_status is not False)

        if overall_success_flag:
            console.print("\n[bold bright_green]All desired backup routines completed successfully or were appropriately skipped.[/bold bright_green]")
            sys.exit(0)
        else:
            console.print("\n[bold red]One or more backup routines encountered significant errors.[/bold red]")
            sys.exit(1)

    except Exception as e:
        # Fallback for truly unexpected errors in the main script logic
        print(f"FATAL ERROR: Unhandled exception in __main__: {e}", file=sys.stderr)
        traceback.print_exc(file=sys.stderr) # Always print traceback for fatal errors
        
        # Try to use the console object for formatted error, if available
        error_msg_display = f"[bold red]FATAL SCRIPT ERROR:[/] {e}\nCheck STDERR for details."
        
        rendered_error_msg = error_msg_display
        if console and hasattr(console, '_render_rich_object_to_plain_text'): # if FallbackConsole
            rendered_error_msg = console._render_rich_object_to_plain_text(error_msg_display)
        elif not RICH_AVAILABLE: # If Rich not available and not FallbackConsole (e.g. console is None)
             # Basic strip if no console or Rich available at all
             rendered_error_msg = re.sub(r'\[.*?\]', '', error_msg_display)

        if RICH_AVAILABLE and console and hasattr(console, 'print_exception'):
            try:
                console.print(error_msg_display) # Print the formatted message
                if isinstance(console, Console): # Ensure it's the Rich Console for print_exception
                     console.print_exception(show_locals=True)
            except Exception as ex_inner:
                 # If Rich fails even here, fallback to basic print
                 print(f"Error trying to print exception with Rich: {ex_inner}", file=sys.stderr)
                 print(rendered_error_msg, file=sys.stderr) # Print the stripped/plain version
        else:
            # If Rich not available or console is FallbackConsole (which doesn't have print_exception)
            print(rendered_error_msg, file=sys.stderr)

        sys.exit(2)
