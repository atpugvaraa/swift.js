'use client';
import { useState } from 'react';

import { Button, Text, VStack } from '@swiftjs/runtime';

export const Counter = () => {
  const [count, setCount] = useState(0);

  return (
    <VStack>
<Text content={`Count is ${count}`} />
<Button title={"Increment"} style={{ padding: 16 }} onClick={() => {
    setCount(count + 1);
}} />
</VStack>
  );
}
