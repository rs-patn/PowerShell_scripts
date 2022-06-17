# SendGrid-Notification 
Function Invoke-SendGridNotification {
  [CmdletBinding()]
  Param(
      [Parameter(Mandatory, ValueFromPipeline)]
      [String]$ToAddress,
      [Parameter(Mandatory, ValueFromPipeline)]
      [String]$FromAddress,
      [Parameter(Mandatory, ValueFromPipeline)]
      [String]$Subject,
      [Parameter(Mandatory, ValueFromPipeline)]
      [String]$Body,
      [Parameter(Mandatory, ValueFromPipeline)]
      [String]$APIKey
  )

  # Body
  $SendGridBody = @{
      "personalizations" = @(
          @{
              "to"      = @(
                  @{
                      "email" = $ToAddress
                  }
              )
              "subject" = $Subject
          }
      )

      "content"          = @(
          @{
              "type"  = "text/html"
              "value" = $Body
          }
      )

      "from"             = @{
          "email" = $FromAddress
      }
  }

  $BodyJson = $SendGridBody | ConvertTo-Json -Depth 4

  #Header for SendGrid API
  $Header = @{
      "authorization" = "Bearer $APIKey"
  }

  #Send the email through SendGrid API
  $Parameters = @{
      Method      = "POST"
      Uri         = "https://api.sendgrid.com/v3/mail/send"
      Headers     = $Header
      ContentType = "application/json"
      Body        = $BodyJson
  }
  Invoke-RestMethod @Parameters
}

# Set these environment variables up in Function App settings:
# These variables are from the Function App and is referenced from Key Vault
$apiKey = $env:sendGridApiKey #SendGrid API Key
$from = $env:fromAddress #SendGrid Sender Address
$to = $env:toAddress #Recipient address

# Set additional variables here

$dateTime = get-date
$expirationDate = $datetime.AddDays(30)
$apps = Get-AzADApplication


foreach ($app in $apps)
{
  $servicePrincipal = $app | Get-AzADAppCredential
  $spExpiration = $servicePrincipal.EndDateTime

  # If any of the secrets expire within 30 days or has expired
  if ($spExpiration -lt $dateTime) {
    # Send notification
    $Expired = @{
      ToAddress   = $to
      FromAddress = $from
      Subject     = "Your Service Principal, $($app.DisplayName), secret has expired"
      Body        = Write-Output "$($app.DisplayName) has <strong><u><i>expired</i></u></strong>!
                    <br><br><br>
                    Please follow the instructions below on renewing the client secret.
                    <br><br>1. Log into Azure and go to <strong>Azure Active Directory</strong>.
                    <br>2. In the left panel, click on <strong>App registrations</strong>.
                    <br>3. Click the <strong>All applications</strong> tab.
                    <br>4. Click on the Service Principal that has or is about to expire.
                    <br>5. Click <strong>Certificates & secrets</strong> in the left panel.
                    <br>6. Renew the client secret. Please make sure to keep track of the new client secret before leaving the page as you will not be able to return and view the secret at a later time period."
      APIKey      = $apiKey
    }
    Invoke-SendGridNotification @Expired
    Write-Output "Email sent for $($app.DisplayName)"

  } elseif ($spExpiration -lt $expirationDate) {
    # Send notification
    $ExpiringSoon = @{
      ToAddress   = $to
      FromAddress = $from
      Subject     = "Your Service Principal, $($app.DisplayName), secret is expiring soon"
      Body        = Write-Output "$($app.DisplayName) is expiring in <strong><u><i>$(((New-TimeSpan -Start ($dateTime) -End ($spExpiration)).Days) + 1)</i></u></strong> day(s)!
                    <br><br><br>
                    Please follow the instructions below on renewing the client secret.
                    <br><br>1. Log into Azure and go to <strong>Azure Active Directory</strong>.
                    <br>2. In the left panel, click on <strong>App registrations</strong>.
                    <br>3. Click the <strong>All applications</strong> tab.
                    <br>4. Click on the Service Principal that has or is about to expire.
                    <br>5. Click <strong>Certificates & secrets</strong> in the left panel.
                    <br>6. Renew the client secret. Please make sure to keep track of the new client secret before leaving the page as you will not be able to return and view the secret at a later time period."
      APIKey      = $apiKey
    }
    Invoke-SendGridNotification @ExpiringSoon
    Write-Output "Email sent for $($app.DisplayName)"

  } else {
    Write-Output "$($app.DisplayName) is not expiring anytime soon!"
  }
}
