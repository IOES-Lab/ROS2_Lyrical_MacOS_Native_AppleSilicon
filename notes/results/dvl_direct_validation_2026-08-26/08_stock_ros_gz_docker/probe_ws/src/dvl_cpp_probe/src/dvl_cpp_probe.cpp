#include <chrono>
#include <iomanip>
#include <iostream>
#include <memory>
#include <thread>
#include <rclcpp/rclcpp.hpp>
#include <marine_acoustic_msgs/msg/dvl.hpp>

int main(int argc, char **argv)
{
  rclcpp::init(argc, argv);
  auto node = std::make_shared<rclcpp::Node>("dvl_cpp_probe");
  bool received = false;
  auto sub = node->create_subscription<marine_acoustic_msgs::msg::Dvl>(
    "/dvl/velocity", rclcpp::QoS(10),
    [&](marine_acoustic_msgs::msg::Dvl::SharedPtr msg) {
      std::cout << std::setprecision(17);
      std::cout << "frame_id=" << msg->header.frame_id << "\n";
      std::cout << "stamp=" << msg->header.stamp.sec << "." << msg->header.stamp.nanosec << "\n";
      std::cout << "velocity_mode=" << static_cast<int>(msg->velocity_mode) << "\n";
      std::cout << "dvl_type=" << static_cast<int>(msg->dvl_type) << "\n";
      std::cout << "velocity=" << msg->velocity.x << "," << msg->velocity.y << "," << msg->velocity.z << "\n";
      std::cout << "altitude=" << msg->altitude << "\n";
      std::cout << "num_good_beams=" << static_cast<int>(msg->num_good_beams) << "\n";
      std::cout << "beam_ranges_valid=" << msg->beam_ranges_valid << "\n";
      std::cout << "beam_velocities_valid=" << msg->beam_velocities_valid << "\n";
      std::cout << "range=";
      for (size_t i = 0; i < msg->range.size(); ++i) {
        if (i) std::cout << ",";
        std::cout << msg->range[i];
      }
      std::cout << "\nbeam_velocity=";
      for (size_t i = 0; i < msg->beam_velocity.size(); ++i) {
        if (i) std::cout << ",";
        std::cout << msg->beam_velocity[i];
      }
      std::cout << "\n";
      received = true;
      rclcpp::shutdown();
    });
  auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(120);
  while (rclcpp::ok() && !received && std::chrono::steady_clock::now() < deadline) {
    rclcpp::spin_some(node);
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
  }
  if (rclcpp::ok()) rclcpp::shutdown();
  return received ? 0 : 2;
}
