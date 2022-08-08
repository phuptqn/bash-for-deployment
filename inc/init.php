<?php

function get_cache_version() {
  $cache_file_path = get_stylesheet_directory() . '/cache-version.txt';
  
  $cache_version = file_get_contents($cache_file_path);
  
  return $cache_version ? $cache_version : '1.0';
}