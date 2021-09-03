# Input Variables
# DB Name
variable "mysql_db_name" {
  description = "Azure MySQL Database Name"
  type        = string
}

# DB Username - Enable Sensitive flag
variable "mysql_db_username" {
  description = "Azure MySQL Database Administrator Username"
  type        = string
}
# DB Password - Enable Sensitive flag
variable "mysql_db_password" {
  description = "Azure MySQL Database Administrator Password"
  type        = string
  sensitive   = true
}

# DB Schema Name
variable "mysql_db_schema" {
  description = "Azure MySQL Database Schema Name"
  type        = string
}