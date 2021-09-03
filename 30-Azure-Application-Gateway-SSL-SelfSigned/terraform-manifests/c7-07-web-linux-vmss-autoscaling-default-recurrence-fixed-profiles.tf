#-----------------------------------------------
# Auto Scaling for Virtual machine scale set
#-----------------------------------------------
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_autoscale_setting

/*
Resource: azurerm_monitor_autoscale_setting
- Notification Block
- Profile Block-1: Default Profile
  1. Capacity Block
  2. Percentage CPU Metric Rules
    1. Scale-Up Rule: Increase VMs by 1 when CPU usage is greater than 75%
    2. Scale-In Rule: Decrease VMs by 1when CPU usage is lower than 25%
  3. Available Memory Bytes Metric Rules
    1. Scale-Up Rule: Increase VMs by 1 when Available Memory Bytes is less than 1GB in bytes
    2. Scale-In Rule: Decrease VMs by 1 when Available Memory Bytes is greater than 2GB in bytes
  4. COMMENT -LB SYN Count Metric Rules (JUST FOR firing Scale-Up and Scale-In Events for Testing and also knowing in addition to current VMSS Resource, we can also create Autoscaling rules for VMSS based on other Resource usage like Load Balancer)
    1. Scale-Up Rule: Increase VMs by 1 when LB SYN Count is greater than 10 Connections (Average)
    2. Scale-Up Rule: Decrease VMs by 1 when LB SYN Count is less than 10 Connections (Average)    
# Adding Profile-4
*/
/*
resource "azurerm_monitor_autoscale_setting" "web_vmss_autoscale" {
  name                = "${local.resource_name_prefix}-web-vmss-autoscale-profiles"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.web_vmss.id
  # Notification  
  notification {
      email {
        send_to_subscription_administrator    = true
        send_to_subscription_co_administrator = true
        custom_emails                         = ["myadminteam@ourorg.com"]
      }
    }    
################################################################################
################################################################################
#######################  Profile-1: Default Profile  ###########################
################################################################################
################################################################################
# Profile-1: Default Profile 
  profile {
    name = "default"
  # Capacity Block     
    capacity {
      default = 2
      minimum = 2
      maximum = 6
    }
###########  START: Percentage CPU Metric Rules  ###########    
  ## Scale-Out 
    rule {
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }            
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"        
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }
    }

  ## Scale-In 
    rule {
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }        
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"                
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }
    }
###########  END: Percentage CPU Metric Rules   ###########    

###########  START: Available Memory Bytes Metric Rules  ###########    
  ## Scale-Out 
    rule {
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }            
      metric_trigger {
        metric_name        = "Available Memory Bytes"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"        
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 1073741824 # Increase 1 VM when Memory In Bytes is less than 1GB
      }
    }

  ## Scale-In 
    rule {
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }        
      metric_trigger {
        metric_name        = "Available Memory Bytes"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"                
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 2147483648 # Decrease 1 VM when Memory In Bytes is Greater than 2GB
      }
    }
###########  END: Available Memory Bytes Metric Rules  ###########  


###########  START: LB SYN Count Metric Rules - Just to Test scale-in, scale-out  ###########    
  ## Scale-Out 
    rule {
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }      
      metric_trigger {
        metric_name        = "SYNCount"
        metric_resource_id = azurerm_lb.web_lb.id 
        metric_namespace   = "Microsoft.Network/loadBalancers"        
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 10 # 10 requests to an LB
      }
    }
  ## Scale-In 
    rule {
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }      
      metric_trigger {
        metric_name        = "SYNCount"
        metric_resource_id = azurerm_lb.web_lb.id
        metric_namespace   = "Microsoft.Network/loadBalancers"                
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 10
      }
    }
###########  END: LB SYN Count Metric Rules  ###########    
  } # End of Profile-1


################################################################################
################################################################################
####################  Profile-2: Recurrence Profile  - Week Days ###############
################################################################################
################################################################################
## Major Changes in this Block
# 1. Capacity Block Values Change - Week Days (Minimum = 4, default = 4, Maximum = 20)
# 2. Recurrence Block for Week Days
# Profile-2: Recurrence Profile - Week Days
  profile {
    name = "profile-2-weekdays"
  # Capacity Block     
    capacity {
      default = 4
      minimum = 4
      maximum = 20
    }
  # Recurrence Block for Week Days (5 days)
    recurrence {
      timezone = "India Standard Time"
      days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
      hours = [0]
      minutes = [0]      
    }    
###########  START: Percentage CPU Metric Rules  ###########    
  ## Scale-Out 
    rule {
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }            
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"        
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }
    }

  ## Scale-In 
    rule {
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }        
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"                
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }
    }
###########  END: Percentage CPU Metric Rules   ###########    

###########  START: Available Memory Bytes Metric Rules  ###########    
  ## Scale-Out 
    rule {
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }            
      metric_trigger {
        metric_name        = "Available Memory Bytes"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"        
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 1073741824 # Increase 1 VM when Memory In Bytes is less than 1GB
      }
    }

  ## Scale-In 
    rule {
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }        
      metric_trigger {
        metric_name        = "Available Memory Bytes"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"                
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 2147483648 # Decrease 1 VM when Memory In Bytes is Greater than 2GB
      }
    }
###########  END: Available Memory Bytes Metric Rules  ###########  


###########  START: LB SYN Count Metric Rules - Just to Test scale-in, scale-out  ###########    
  ## Scale-Out 
    rule {
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }      
      metric_trigger {
        metric_name        = "SYNCount"
        metric_resource_id = azurerm_lb.web_lb.id 
        metric_namespace   = "Microsoft.Network/loadBalancers"        
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 10 # 10 requests to an LB
      }
    }
  ## Scale-In 
    rule {
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }      
      metric_trigger {
        metric_name        = "SYNCount"
        metric_resource_id = azurerm_lb.web_lb.id
        metric_namespace   = "Microsoft.Network/loadBalancers"                
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 10
      }
    }
###########  END: LB SYN Count Metric Rules  ###########    
  } # End of Profile-2

################################################################################
################################################################################
####################  Profile-3: Recurrence Profile  - Weekends ###############
################################################################################
################################################################################
## Major Changes in this Block
# 1. Capacity Block Values Change - Weekends (Minimum = 3, default = 3, Maximum = 20)
# 2. Recurrence Block for Weekends
# Profile-3: Recurrence Profile - Weekends
  profile {
    name = "profile-3-weekends"
  # Capacity Block     
    capacity {
      default = 3
      minimum = 3
      maximum = 6
    }
  # Recurrence Block for Weekends (2 days)
    recurrence {
      timezone = "India Standard Time"
      days = ["Saturday", "Sunday"]
      hours = [0]
      minutes = [0]      
    }    
###########  START: Percentage CPU Metric Rules  ###########    
  ## Scale-Out 
    rule {
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }            
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"        
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }
    }

  ## Scale-In 
    rule {
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }        
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"                
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }
    }
###########  END: Percentage CPU Metric Rules   ###########    

###########  START: Available Memory Bytes Metric Rules  ###########    
  ## Scale-Out 
    rule {
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }            
      metric_trigger {
        metric_name        = "Available Memory Bytes"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"        
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 1073741824 # Increase 1 VM when Memory In Bytes is less than 1GB
      }
    }

  ## Scale-In 
    rule {
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }        
      metric_trigger {
        metric_name        = "Available Memory Bytes"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"                
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 2147483648 # Decrease 1 VM when Memory In Bytes is Greater than 2GB
      }
    }
###########  END: Available Memory Bytes Metric Rules  ###########  


###########  START: LB SYN Count Metric Rules - Just to Test scale-in, scale-out  ###########    
  ## Scale-Out 
    rule {
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }      
      metric_trigger {
        metric_name        = "SYNCount"
        metric_resource_id = azurerm_lb.web_lb.id 
        metric_namespace   = "Microsoft.Network/loadBalancers"        
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 10 # 10 requests to an LB
      }
    }
  ## Scale-In 
    rule {
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }      
      metric_trigger {
        metric_name        = "SYNCount"
        metric_resource_id = azurerm_lb.web_lb.id
        metric_namespace   = "Microsoft.Network/loadBalancers"                
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 10
      }
    }
###########  END: LB SYN Count Metric Rules  ###########    
} # End of Profile-3



################################################################################
################################################################################
####################  Profile-4: Fixed Profile - Specific Day ##################
################################################################################
################################################################################
## Major Changes in this Block
# 1. Capacity Block Values Change  (Minimum = 5, default = 5, Maximum = 20)
# 2. Fixed  Block for a specific day
# Profile-4: Fixed Profile for a Specific Day
  profile {
    name = "profile-4-fixed-profile"
  # Capacity Block     
    capacity {
      default = 5
      minimum = 5
      maximum = 20
    }
  # Fixed Block for a specific day
    fixed_date {
      timezone = "India Standard Time"
      start    = "2021-08-16T00:00:00Z"  # CHANGE TO THE DATE YOU ARE TESTING
      end      = "2021-08-16T23:59:59Z"  # CHANGE TO THE DATE YOU ARE TESTING
    }  
###########  START: Percentage CPU Metric Rules  ###########    
  ## Scale-Out 
    rule {
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }            
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"        
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }
    }

  ## Scale-In 
    rule {
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }        
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"                
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }
    }
###########  END: Percentage CPU Metric Rules   ###########    

###########  START: Available Memory Bytes Metric Rules  ###########    
  ## Scale-Out 
    rule {
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }            
      metric_trigger {
        metric_name        = "Available Memory Bytes"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"        
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 1073741824 # Increase 1 VM when Memory In Bytes is less than 1GB
      }
    }

  ## Scale-In 
    rule {
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }        
      metric_trigger {
        metric_name        = "Available Memory Bytes"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"                
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 2147483648 # Decrease 1 VM when Memory In Bytes is Greater than 2GB
      }
    }
###########  END: Available Memory Bytes Metric Rules  ###########  


###########  START: LB SYN Count Metric Rules - Just to Test scale-in, scale-out  ###########    
  ## Scale-Out 
    rule {
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }      
      metric_trigger {
        metric_name        = "SYNCount"
        metric_resource_id = azurerm_lb.web_lb.id 
        metric_namespace   = "Microsoft.Network/loadBalancers"        
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 10 # 10 requests to an LB
      }
    }
  ## Scale-In 
    rule {
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }      
      metric_trigger {
        metric_name        = "SYNCount"
        metric_resource_id = azurerm_lb.web_lb.id
        metric_namespace   = "Microsoft.Network/loadBalancers"                
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 10
      }
    }
###########  END: LB SYN Count Metric Rules  ###########    
} # End of Profile-4



}
*/