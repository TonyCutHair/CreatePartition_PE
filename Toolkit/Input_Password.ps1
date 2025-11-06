# Load the required assemblies
Add-Type -AssemblyName System.Windows.Forms

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Password Input'
$form.Width = 300
$form.Height = 150
$form.StartPosition = 'CenterScreen'

# Create the password label
$passwordLabel = New-Object System.Windows.Forms.Label
$passwordLabel.Text = 'Enter Password:'
$passwordLabel.AutoSize = $true
$passwordLabel.Top = 20
$passwordLabel.Left = 20
$form.Controls.Add($passwordLabel)

# Create the password textbox
$passwordTextBox = New-Object System.Windows.Forms.MaskedTextBox
$passwordTextBox.PasswordChar = '*'
$passwordTextBox.Width = 200
$passwordTextBox.Top = 20
$passwordTextBox.Left = 120
$form.Controls.Add($passwordTextBox)

# Create the OK button
$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = 'OK'
$okButton.Top = 60
$okButton.Left = 120
$okButton.Add_Click({
		# Check if the entered password matches the stored password
		$storedPassword = 'YourStoredPassword' # Replace with your actual stored password
		if ($passwordTextBox.Text -eq $storedPassword)
		{
			$form.Close()
		}
		else
		{
			[System.Windows.Forms.MessageBox]::Show('Incorrect password. Please try again.')
			$passwordTextBox.Clear()
		}
	})
$form.Controls.Add($okButton)

# Display the form
$form.ShowDialog()
