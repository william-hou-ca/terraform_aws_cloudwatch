provider "aws" {
  region = "ca-central-1"
}

###########################################################################
#
# Create a clouldwatch dashboard
# details in the page https://docs.aws.amazon.com/AmazonCloudWatch/latest/APIReference/CloudWatch-Dashboard-Body-Structure.html
#
###########################################################################

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "tf-my-dashboard"

  dashboard_body = <<EOF
{
  "start": "-PT1H",
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [
            "AWS/EC2",
            "CPUUtilization",
            "InstanceId",
            "${aws_instance.web.id}"
          ],
          [
            ".",
            "NetworkIn",
            ".",
            ".",
            { "yAxis": "right" }
          ]
        ],
        "period": 300,
        "stat": "Average",
        "region": "ca-central-1",
        "title": "EC2 Instance CPU",
        "yAxis": {
            "right": {
                "min": 0,
                "max": 100000000
            },
            "left": {
                "min": 0,
                "max": 100
            }
         }
      }
    },
    {
      "type": "text",
      "x": 0,
      "y": 7,
      "width": 3,
      "height": 3,
      "properties": {
        "markdown": "Hello world"
      }
    },
    {
      "type": "alarm",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
          "alarms": [
              "${aws_cloudwatch_metric_alarm.ma_cpu.arn}"
          ],
          "sortBy": "stateUpdatedTimestamp",
          "title": "All EC2 CPU alarms"
        }
    }  
  ]
}
EOF
}

###########################################################################
#
# Create a clouldwatch alarm which moniters one ec2 instance
#
###########################################################################

resource "aws_cloudwatch_metric_alarm" "ma_cpu" {

  # Metric
  namespace                 = "AWS/EC2"
  metric_name               = "CPUUtilization"
  dimensions                = {
        "InstanceId" = aws_instance.web.id
    }
  statistic                 = "Average"
  period                    = "300"
  
  # Conditions
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  threshold                 = "80"
  ## Additional configuration
  datapoints_to_alarm       = 2
  evaluation_periods        = 3
  treat_missing_data        = "missing"

  # Configure actions
  insufficient_data_actions = []
  ok_actions                = []
  alarm_actions     = []

  # Name and description
  alarm_name                = "tf-alarm-cpu"
  alarm_description         = "This metric monitors ec2 cpu utilization"
}

###########################################################################
#
# Create a clouldwatch alarm which moniters an asg
#
###########################################################################

resource "aws_cloudwatch_metric_alarm" "ma_asg" {

  # Metric
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }
  statistic           = "Average"
  period              = "120"

  # Conditions
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = "70"
  evaluation_periods  = "2"
  treat_missing_data        = "missing"

  # Configure actions
  alarm_actions     = [aws_autoscaling_policy.this.arn]

  # Name and description
  alarm_name          = "tf-alarm-asg-cpu"
  alarm_description = "This metric monitors cpu utilization ec2s in an asg."

}

# descrease instances' number with expression
resource "aws_cloudwatch_metric_alarm" "ma_asg_decrease" {

  # Metric
  metric_query {
    id          = "e1"
    expression  = "IF(m1 > 30 AND m1 < 50, 1, 0)"
    label       = "normal cpu load "
    return_data = "true"
  }

  metric_query {
    id = "m1"

    metric {
      metric_name = "CPUUtilization"
      namespace   = "AWS/EC2"
      period      = "120"
      stat        = "Average"

      dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.this.name
      }
    }
  }

  # Conditions
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = "1"
  evaluation_periods  = "2"
  treat_missing_data        = "missing"

  # Configure actions
  alarm_actions     = [aws_autoscaling_policy.remove_units.arn]

  # Name and description
  alarm_name          = "tf-alarm-asg-cpu-descrease"
  alarm_description = "This metric monitors cpu utilization ec2s in an asg."

}

# alarm with expression
resource "aws_cloudwatch_metric_alarm" "ma_exp" {
  alarm_name                = "tf-alarm-exp"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  threshold                 = "500000000"
  alarm_description         = "Bytes in total has exceeded 500m bits"
  insufficient_data_actions = []

  metric_query {
    id          = "e1"
    expression  = "SUM(METRICS())*8"
    label       = "incoming and outgoing bits"
    return_data = "true"
  }

  metric_query {
    id = "m1"

    metric {
      metric_name = "NetworkIn"
      namespace   = "AWS/EC2"
      period      = "300"
      stat        = "Average"
      unit        = "Bytes"

      dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.this.name
      }
    }
  }

  metric_query {
    id = "m2"

    metric {
      metric_name = "NetworkOut"
      namespace   = "AWS/EC2"
      period      = "300"
      stat        = "Average"
      unit        = "Bytes"

      dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.this.name
      }
    }
  }
}

# alarm using anomaly detection
/*
resource "aws_cloudwatch_metric_alarm" "xx_anomaly_detection" {
  alarm_name                = "terraform-test-foobar"
  comparison_operator       = "GreaterThanUpperThreshold"
  evaluation_periods        = "2"
  threshold_metric_id       = "e1"
  alarm_description         = "This metric monitors ec2 cpu utilization"
  insufficient_data_actions = []

  metric_query {
    id          = "e1"
    expression  = "ANOMALY_DETECTION_BAND(m1)"
    label       = "CPUUtilization (Expected)"
    return_data = "true"
  }

  metric_query {
    id          = "m1"
    return_data = "true"
    metric {
      metric_name = "CPUUtilization"
      namespace   = "AWS/EC2"
      period      = "120"
      stat        = "Average"
      unit        = "Count"

      dimensions = {
        InstanceId = "i-abc123"
      }
    }
  }
}
*/
###########################################################################
#
# ec2 instance in the default vpc
#
###########################################################################

resource "aws_instance" "web" {
  #count = 0 #if count = 0, this instance will not be created.

  #required parametres
  ami           = "ami-09934b230a2c41883"
  instance_type = "t2.micro"

  #optional parametres
  associate_public_ip_address = true
  key_name = "key-hr123000" #key paire name exists in aws.

  vpc_security_group_ids = data.aws_security_groups.default_sg.ids

  tags = {
    Name = "HelloWorld"
  }

  user_data = <<-EOF
          #! /bin/sh
          sudo yum update -y
          sudo amazon-linux-extras install epel -y 
          sudo amazon-linux-extras install -y nginx1
          sudo systemctl start nginx
          curl -s http://169.254.169.254/latest/meta-data/local-hostname | sudo tee /usr/share/nginx/html/index.html
          sudo yum install httpd-tools -y
EOF

lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      user_data,
    ]
  }
}

###########################################################################
#
# Create an autoscaling group in the default vpc
#
###########################################################################

resource "aws_launch_template" "this" {
  name_prefix   = "tf-asg-template"
  image_id      = "ami-09934b230a2c41883"
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups = data.aws_security_groups.default_sg.ids
  }

  key_name = "key-hr123000" #key paire name exists in aws.

  user_data = base64encode(<<-EOF
          #! /bin/sh
          sudo yum update -y
          sudo amazon-linux-extras install epel -y 
          sudo amazon-linux-extras install -y nginx1
          sudo systemctl start nginx
          curl -s http://169.254.169.254/latest/meta-data/local-hostname | sudo tee /usr/share/nginx/html/index.html
          sudo yum install httpd-tools -y
EOF
)

  tags = {
    Name = "tf-asg-template"
  }

}

resource "aws_autoscaling_group" "this" {
  desired_capacity   = 2
  max_size           = 4
  min_size           = 1
  vpc_zone_identifier = data.aws_subnet_ids.default_subnets.ids

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  lifecycle {
    ignore_changes = [ desired_capacity, ]
  }
}

resource "aws_autoscaling_policy" "this" {
  name                   = "tf-asg-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  #cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.this.name
}

resource "aws_autoscaling_policy" "remove_units" {
  name                   = "tf-asg-policy-decrease"
  scaling_adjustment     = -2
  adjustment_type        = "ChangeInCapacity"
  #cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.this.name
}